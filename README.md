# CFML AI Agents

AI agents that reason and act, built in ColdFusion.

An agent framework for CFML that implements the **ReAct (Reason + Act) pattern** for LLM-driven tool use. Define tools as CFCs, hand them to an agent, and let the LLM decide how to use them to accomplish a task. Think LangChain, but for ColdFusion.

## How It Works

The agent follows a reasoning loop:

```
User Task
    |
    v
+-------------------+
|   LLM Thinks      |  <-- "I need to search the web for this"
+-------------------+
    |
    v
+-------------------+
|   Tool Execution  |  <-- web_search("CFML 2026 news")
+-------------------+
    |
    v
+-------------------+
|   Observe Result  |  <-- "Found 5 results about..."
+-------------------+
    |
    v
  Need more info? ---Yes---> Back to LLM Thinks
    |
    No
    |
    v
+-------------------+
|   Final Answer    |  <-- "Here's what I found..."
+-------------------+
```

Each cycle is a "step." The agent keeps going until it has enough information to answer (or hits the step limit). Every tool call, its inputs, and its results are captured in an execution trace you can inspect.

## Quick Start

### With CommandBox

```bash
git clone https://github.com/tachyurgy/cfml-ai-agents.git
cd cfml-ai-agents
cp .env.example .env
# Edit .env with your API keys
box server start
```

Open http://localhost:8501 in your browser.

### With Docker

```bash
git clone https://github.com/tachyurgy/cfml-ai-agents.git
cd cfml-ai-agents
cp .env.example .env
# Edit .env with your API keys
docker-compose up -d
```

Open http://localhost:8501.

## Configuration

Copy `.env.example` to `.env` and fill in your keys:

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key (for Claude) |
| `OPENAI_API_KEY` | Your OpenAI API key (alternative provider) |
| `LLM_PROVIDER` | `anthropic` or `openai` |
| `LLM_MODEL` | Model name (e.g., `claude-sonnet-4-6-20250514`, `gpt-4o`) |
| `SERPAPI_KEY` | SerpAPI key for web search (optional, falls back to mock) |

## Built-in Tools

### web_search
Search the web for current information using SerpAPI. Falls back to a mock response if no API key is set.
- **Parameters:** `query` (string)

### http_request
Fetch data from any public URL. Strips HTML for readability and truncates long responses.
- **Parameters:** `url` (string), `method` (string, default GET)

### query_database
Run read-only SQL against a demo database with `products`, `customers`, and `orders` tables. Only SELECT statements are allowed.
- **Parameters:** `sql` (string)

### calculator
Evaluate mathematical expressions safely. Supports arithmetic, exponents, trig, and common math functions.
- **Parameters:** `expression` (string)

### datetime
Date/time operations: get current time, add intervals, compute differences, format dates.
- **Parameters:** `operation` (now|add|diff|format), `value` (string, optional)

## Creating Custom Tools

Extend `models/Tool.cfc` and override `execute()`:

```cfml
component extends="models.Tool" {

    public function init() {
        super.init(
            name = "weather",
            description = "Get the current weather for a city",
            parameters = {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "City name"
                    }
                },
                "required": ["city"]
            }
        );
        return this;
    }

    public struct function execute(required struct args) {
        // Your implementation here
        var city = arguments.args.city;
        // ... call a weather API ...
        return {"result": "72F and sunny in #city#"};
    }

}
```

Register it in `Application.cfc`:

```cfml
application.toolRegistry.register(new models.tools.WeatherTool());
```

The agent will automatically see it and use it when relevant.

## API

### POST /api/agent/run

Run the agent on a task and get the result with full execution trace.

**Request:**
```json
{
    "task": "What is 2^10 and what day of the week is it?",
    "maxSteps": 10
}
```

**Response:**
```json
{
    "success": true,
    "result": "2^10 is 1024. Today is Tuesday.",
    "trace": {
        "task": "...",
        "steps": [
            {
                "step": 1,
                "type": "tool_use",
                "toolCall": {"name": "calculator", "arguments": {"expression": "2^10"}},
                "toolResult": {"result": "1024", "success": true}
            },
            {
                "step": 2,
                "type": "tool_use",
                "toolCall": {"name": "datetime", "arguments": {"operation": "now"}},
                "toolResult": {"result": "...Tuesday...", "success": true}
            },
            {
                "step": 3,
                "type": "answer",
                "response": "2^10 is 1024. Today is Tuesday."
            }
        ],
        "totalSteps": 3,
        "status": "completed"
    }
}
```

### GET /api/tools

List all registered tools and their schemas.

### POST /api/agent/stream

Server-Sent Events endpoint. Same request body as `/agent/run`, but streams events as the agent works:

- `start` - Agent begins processing
- `thought` - Agent's reasoning text
- `tool_call` - Tool being invoked with arguments
- `tool_result` - Tool's response
- `answer` - Final answer
- `done` - Execution complete

## Architecture

```
Application.cfc          -- Bootstraps registry, provider, tools
  |
  +-- models/
  |     Agent.cfc        -- ReAct loop: think -> act -> observe -> repeat
  |     LLMProvider.cfc  -- Anthropic + OpenAI API abstraction
  |     Tool.cfc         -- Base class for all tools
  |     ToolRegistry.cfc -- Tool storage and lookup
  |     ConversationMemory.cfc -- Message history + summarization
  |     tools/
  |       WebSearchTool.cfc
  |       HttpRequestTool.cfc
  |       DatabaseQueryTool.cfc
  |       CalculatorTool.cfc
  |       DateTimeTool.cfc
  |
  +-- handlers/
  |     api.cfc          -- REST endpoints
  |
  +-- index.cfm          -- Web UI
```

The LLM never executes code directly. It can only request tool calls by name. The agent validates arguments against each tool's JSON Schema before execution, and tools like `query_database` enforce their own safety constraints (read-only SQL, no internal URLs, etc.).

## Example Agent Runs

**Task:** "What are the top 3 most expensive products in the database?"

1. Agent calls `query_database` with `SELECT name, price FROM products ORDER BY price DESC LIMIT 3`
2. Gets back: Standing Desk ($449), Noise-Canceling Headphones ($279.99), Mechanical Keyboard ($149.99)
3. Formats and returns the answer

**Task:** "How many days until the year 2030?"

1. Agent calls `datetime` with operation `now` to get the current date
2. Agent calls `datetime` with operation `diff`, value `2026-04-08 to 2030-01-01`
3. Combines the results into a final answer

**Task:** "Search for ColdFusion news and summarize what you find"

1. Agent calls `web_search` with query "ColdFusion CFML news 2026"
2. Agent may call `http_request` to fetch a promising article URL
3. Synthesizes findings into a summary

## License

MIT
