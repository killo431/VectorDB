FROM python:3.11-slim

WORKDIR /app

# Install build dependencies for tantivy/lancedb
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Keep the container running to interact via CLI
CMD ["python", "app.py"]
