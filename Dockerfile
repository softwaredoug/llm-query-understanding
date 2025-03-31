FROM nvidia/cuda:11.8.0-base-ubuntu22.04

RUN apt-get update && apt-get install --no-install-recommends -y \
        build-essential \
        python3.10 \
        python3-pip && \
    	apt clean && rm -rf /var/lib/apt/lists/*

# Set workdir
WORKDIR /app

# Install Poetry
RUN pip3 install poetry

# Copy pyproject files
COPY pyproject.toml poetry.lock* /app/

# Install dependencies
RUN poetry config virtualenvs.create false \
    && poetry install --no-root --no-cache

# Copy app
COPY llm_query_understand /app/llm_query_understand

# Run the app
CMD ["uvicorn", "llm_query_understand.app:app", "--host", "0.0.0.0", "--port", "80"]
