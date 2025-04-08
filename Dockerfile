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
RUN poetry config virtualenvs.create false

# Install only the "slow" group (torch), which should change infrequently
RUN poetry install --only slow --no-root --no-cache

# For quantization, and this module is its own special snowflake
# # https://github.com/ModelCloud/GPTQModel/issues/1466
RUN poetry run pip install -v gptqmodel --no-build-isolation

# Install the rest of the dependencies
RUN poetry install --without slow --no-root --no-cache

# Copy app
COPY llm_query_understand /app/llm_query_understand

# Run the app
CMD ["uvicorn", "llm_query_understand.app:app", "--host", "0.0.0.0", "--port", "80"]
