from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from llm_query_understand.llm import LargeLanguageModel
from time import perf_counter
import hashlib
import json
import redis

app = FastAPI()
llm = LargeLanguageModel()
r = redis.Redis(host='val-key', port=6379, decode_responses=True)

PROMPT = """
You are a helpful assistant. You will be given a search query and you need to parse furniture searches it into a structured format. The structured format should include the following fields:

    - item type - the core thing the user wants (sofa, table, chair, etc.)
    - material - the material of the item (wood, metal, plastic, etc.)
    - color - the color of the item (red, blue, green, etc.)

    Respond with a single line of JSON:

        {"item_type": "sofa", "material": "wood", "color": "red"}

    Omit any other information. Do not include any other text in your response. Omit a value if the user did not specify it. For example, if the user said "red sofa", you would respond with:

        {"item_type": "sofa", "color": "red"}

Here is the search query: """

PROMPT_HASH = hashlib.sha256(PROMPT.encode()).hexdigest()[:8]


@app.post("/parse")
async def q_understand(request: Request):
    print("Received request")
    body = await request.json()
    query = body.get("query")
    if not query:
        return JSONResponse(status_code=400, content={"error": "No query provided"})
    if not isinstance(query, str):
        return JSONResponse(status_code=400, content={"error": "Query must be a string"})

    cache_key = f"query:{PROMPT_HASH}:{query}"
    cached_response = r.get(cache_key)
    if cached_response:
        print("Cache hit")
        return JSONResponse(content=json.loads(cached_response))

    start = perf_counter()
    print(f"Responding to search query: {query}")

    prompt = PROMPT + query

    response = llm.generate(prompt, max_length=100)
    generation_time = perf_counter() - start
    print(f"Generation time: {generation_time:.2f} seconds")
    parsed_query_as_json = response.split("\n")[-1]
    try:
        parsed_query_as_json = json.loads(parsed_query_as_json)
    except json.JSONDecodeError:
        return JSONResponse(status_code=500, content={"error": "Failed to parse response from LLM"})
    print(f"Parsed query: {parsed_query_as_json}")
    r.set(cache_key, json.dumps(parsed_query_as_json), ex=3600)
    resp = {
        "generation_time": generation_time,
        "response": response,
        "prompt": prompt,
        "query": query,
        "parsed_query": parsed_query_as_json,
    }
    return JSONResponse(content=resp)


print("App started")

# Test redis
r.set("test", "test")
print("Redis test key set")
test_value = r.get("test")
print(f"Redis test key value: {test_value}")
