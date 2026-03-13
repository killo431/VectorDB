import os
import glob
import lancedb
import voyageai
from langchain_text_splitters import RecursiveCharacterTextSplitter
from lancedb.rerankers import LinearCombinationReranker
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser

# --- 1. CONFIGURATION ---
PS_SCRIPTS_FOLDER = "/app/data/scripts"
DB_PATH = "/app/data/vectordb"

vo = voyageai.Client(api_key=os.environ["VOYAGE_API_KEY"])
llm = ChatGoogleGenerativeAI(model="gemini-1.5-pro", temperature=0.2)
db = lancedb.connect(DB_PATH)
reranker = LinearCombinationReranker(weight=0.7)

# --- 2. DATABASE INITIALIZATION ---
def initialize_db():
    if "powershell_docs" in db.table_names():
        print("Database already exists. Skipping ingestion...")
        return db.open_table("powershell_docs")

    print("Building VectorDB from scripts...")
    splitter = RecursiveCharacterTextSplitter(
        separators=["\nfunction ", "\n{", "\n}", "\n\n", "\n", " "],
        chunk_size=1500,
        chunk_overlap=200
    )

    chunks, metadata = [], []
    for file_path in glob.glob(f"{PS_SCRIPTS_FOLDER}/**/*.ps1", recursive=True):
        with open(file_path, 'r', encoding='utf-8') as f:
            file_chunks = splitter.split_text(f.read())
            chunks.extend(file_chunks)
            metadata.extend([{"file_path": file_path}] * len(file_chunks))

    if not chunks:
        raise ValueError(f"No .ps1 files found in {PS_SCRIPTS_FOLDER}")

    BATCH_SIZE = 100
    embeddings = []
    for i in range(0, len(chunks), BATCH_SIZE):
        batch = chunks[i:i + BATCH_SIZE]
        batch_embeddings = vo.embed(batch, model="voyage-code-3", input_type="document").embeddings
        embeddings.extend(batch_embeddings)
        print(f"  Embedded {min(i + BATCH_SIZE, len(chunks))}/{len(chunks)} chunks...")

    data = [{"id": str(i), "file_path": metadata[i]["file_path"], "text": chunks[i], "vector": embeddings[i]}
            for i in range(len(chunks))]

    table = db.create_table("powershell_docs", data=data)
    table.create_fts_index("text")
    print("Database built successfully!")
    return table

table = initialize_db()

# --- 3. CUSTOM RETRIEVER FUNCTION ---
def retrieve_context(query: str) -> str:
    """Runs the Hybrid Search and formats the results into a string for the LLM."""
    query_embedding = vo.embed([query], model="voyage-code-3", input_type="query").embeddings[0]

    results = (
        table.search(query_type="hybrid")
        .vector(query_embedding)
        .text(query)
        .rerank(reranker=reranker)
        .limit(4)
        .to_pandas()
    )

    # Format the retrieved chunks into a single string
    context = ""
    for _, row in results.iterrows():
        context += f"\n/// Source File: {row['file_path']} ///\n{row['text']}\n"
    return context

# --- 4. LANGCHAIN PIPELINE ---
prompt = ChatPromptTemplate.from_template("""
You are an expert PowerShell developer. Answer the user's question using ONLY the provided context from our internal dataset.
If the answer is not in the context, say "I don't have enough information in the dataset."

Context:
{context}

Question: {question}

Answer with working PowerShell code and a brief explanation:
""")

# LCEL Chain: Pass question -> Retrieve Context -> Build Prompt -> Call LLM -> Parse String
rag_chain = (
    {"context": retrieve_context, "question": RunnablePassthrough()}
    | prompt
    | llm
    | StrOutputParser()
)

# --- 5. INTERACTIVE CLI LOOP ---
print("\n=== PowerShell RAG Copilot Online ===")
print("Type 'exit' or 'quit' to stop.\n")

while True:
    user_query = input("\nAsk a PowerShell question: ")
    if user_query.lower() in ['exit', 'quit']:
        break

    print("\nThinking...\n")
    # Stream the response back to the terminal
    for chunk in rag_chain.stream(user_query):
        print(chunk, end="", flush=True)
    print("\n")
