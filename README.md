# StockBoy

> **Status:** Architecture & feature planning — no production code yet.

---

## Vision

StockBoy is an AI-powered trading companion — a "friend" that watches the markets on your behalf, surfaces actionable trade ideas, and (with your approval) executes those trades. It combines structured market data with unstructured signals from news and social media, feeds everything through an AI reasoning layer, and presents a concise, conversational interface so that you always understand *why* a suggestion is being made before any money moves.

---

## Core Features

| # | Feature | Description |
|---|---------|-------------|
| 1 | **Market Scanner** | Continuously scans equities, ETFs, and options for user-defined criteria (price breakouts, unusual volume, RSI extremes, earnings catalysts, etc.). |
| 2 | **Idea Generator** | LLM-based agent that synthesizes market data + news + social sentiment into ranked, plain-English trade ideas with supporting evidence. |
| 3 | **Trade Executor** | Routes approved orders to a broker API; supports market, limit, stop, and bracket orders; logs every execution with full audit trail. |
| 4 | **Watchlist & Alerts** | User-managed watchlists with configurable price, volume, and sentiment alerts delivered via push notification, email, or chat (Slack/Discord). |
| 5 | **Portfolio Tracker** | Real-time P&L dashboard, position sizing, risk metrics (beta, drawdown, VaR), and trade history. |
| 6 | **Backtester** | Replay historical market data through scanning rules to evaluate strategy performance before going live. |
| 7 | **Conversational Interface** | Chat-style UI / CLI where users ask questions ("Why is AAPL down today?") and get grounded, cited answers from StockBoy. |

---

## Data Feeds

### Market Data
| Source | Type | Notes |
|--------|------|-------|
| [Alpaca Markets](https://alpaca.markets) | Real-time & historical OHLCV, streaming WebSocket | Free tier available; also provides brokerage API |
| [Polygon.io](https://polygon.io) | Tick data, aggregates, options chain | Good free tier; REST + WebSocket |
| [Yahoo Finance (yfinance)](https://pypi.org/project/yfinance/) | Historical OHLCV, fundamentals | Unofficial; good for prototyping |
| [Alpha Vantage](https://www.alphavantage.co) | Technicals, fundamentals, Forex, Crypto | Free API key; rate-limited |
| [FRED (Federal Reserve)](https://fred.stlouisfed.org/docs/api/fred/) | Macro indicators (CPI, rates, GDP) | Free, authoritative |

### News
| Source | Type | Notes |
|--------|------|-------|
| [Benzinga](https://www.benzinga.com/apis) | Real-time financial news | Premium; high quality |
| [NewsAPI](https://newsapi.org) | Aggregated news search | Free tier; broad coverage |
| [SEC EDGAR RSS](https://www.sec.gov/cgi-bin/browse-edgar) | 8-K, 10-K, 10-Q filings | Free; authoritative regulatory source |
| [Seeking Alpha](https://seekingalpha.com/api) | Analysis articles, earnings transcripts | Premium |

### Social & Sentiment
| Source | Type | Notes |
|--------|------|-------|
| [StockTwits API](https://api.stocktwits.com/developers/docs) | Stock-specific social stream | Already partially integrated in old code |
| [Reddit (Pushshift / PRAW)](https://praw.readthedocs.io) | r/wallstreetbets, r/stocks, r/investing | Free; good for retail sentiment |
| [X (Twitter) API v2](https://developer.x.com/en/docs) | Real-time cashtag streams (`$AAPL`) | Paid tiers required for reliable streaming |
| [Google Trends](https://trends.google.com/trends) | Search interest over time | Free; useful as a leading indicator |

### Alternative Data (Phase 2+)
- Options flow / dark pool prints (e.g., Unusual Whales, Blackbox Stocks)
- Insider transactions (SEC Form 4 via EDGAR)
- Satellite / geolocation data (e.g., foot traffic at retailers)
- Earnings call transcripts (NLP sentiment)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interfaces                         │
│          Web Dashboard  │  Chat UI  │  Mobile  │  CLI           │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTPS / WebSocket
┌───────────────────────────────▼─────────────────────────────────┐
│                         API Gateway                             │
│               (authentication, rate-limiting, routing)          │
└──────┬──────────────┬─────────────────┬───────────────┬─────────┘
       │              │                 │               │
┌──────▼──────┐ ┌─────▼──────┐ ┌───────▼──────┐ ┌──────▼──────┐
│  Scanner    │ │  Idea Gen  │ │  Trade Exec  │ │  Portfolio  │
│  Service   │ │  Service   │ │  Service     │ │  Service    │
│            │ │  (AI Agent)│ │              │ │             │
└──────┬──────┘ └─────┬──────┘ └───────┬──────┘ └──────┬──────┘
       │              │                │               │
       └──────────────┴────────┬───────┴───────────────┘
                               │
              ┌────────────────▼───────────────┐
              │          Message Bus           │
              │     (e.g. RabbitMQ / Kafka)    │
              └──────────┬─────────────────────┘
                         │
       ┌─────────────────┼──────────────────┐
       │                 │                  │
┌──────▼──────┐  ┌───────▼──────┐  ┌────────▼──────┐
│  Ingestion  │  │  AI / LLM    │  │  Persistence  │
│  Pipeline  │  │  Layer       │  │  Layer        │
│            │  │  (reasoning, │  │  (TimescaleDB │
│ • Market   │  │   grounding, │  │   + Redis     │
│ • News     │  │   tool calls)│  │   + Object    │
│ • Social   │  │              │  │   Store)      │
└──────┬──────┘  └───────┬──────┘  └───────────────┘
       │                 │
┌──────▼──────────────────▼─────────────────────────┐
│              External Data Sources                 │
│  Alpaca · Polygon · StockTwits · NewsAPI · EDGAR  │
│  Reddit · X · Alpha Vantage · FRED · SEC EDGAR    │
└────────────────────────────────────────────────────┘
```

### Component Descriptions

#### Ingestion Pipeline
- Normalizes all incoming data into a canonical schema (`{symbol, timestamp, source, payload}`)
- Handles deduplication, back-pressure, and retries
- Writes raw events to the object store for auditability and backtesting replay
- Publishes normalised events onto the message bus

#### Scanner Service
- Subscribes to market-data events on the message bus
- Evaluates user-defined rules (technical indicators, volume anomalies, options flow)
- Emits `ScanHit` events when criteria are met

#### Idea Generation Service (AI Agent)
- Subscribes to `ScanHit` events, recent news, and social sentiment
- Uses an LLM (e.g. OpenAI GPT-4o, Anthropic Claude, or a locally hosted model) with **tool-calling** to:
  - Pull supporting data on demand (price history, news summaries, SEC filings)
  - Generate a structured trade thesis: entry, target, stop, position size, time horizon, confidence
  - Provide cited reasoning so users can audit the suggestion
- Ideas are stored and surfaced via the API Gateway

#### Trade Execution Service
- Receives approved orders from the user (explicit approval always required for real money)
- Routes to broker APIs (Alpaca, Interactive Brokers, TD Ameritrade via thinkorswim)
- Implements smart order routing: slippage minimisation, partial fills handling
- Enforces risk controls: max position size, daily loss limit, market-hours checks
- Publishes execution events back onto the message bus

#### Portfolio Service
- Maintains real-time positions by consuming execution events
- Calculates P&L, unrealised gains, risk metrics
- Stores historical snapshots for performance analytics

#### AI / LLM Layer
- Central reasoning engine shared across services
- Supports multiple model providers via a unified interface (LiteLLM or similar abstraction)
- Retrieval-Augmented Generation (RAG) over historical news & filings using a vector store (e.g. pgvector or Qdrant)
- Prompt templates version-controlled alongside the codebase
- All LLM calls logged for evaluation and fine-tuning

---

## Technology Choices & Rationale

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Core services** | Elixir / Phoenix (existing) | Excellent concurrency model (BEAM) ideal for high-frequency event streams and fault-tolerant supervisors |
| **AI / LLM** | Python microservice (FastAPI) | Best ecosystem for LangChain / LlamaIndex / OpenAI SDK; bridges to Elixir via HTTP or gRPC |
| **Message bus** | RabbitMQ (start) → Kafka (scale) | RabbitMQ is easy to operate locally; Kafka for high-throughput production |
| **Time-series data** | TimescaleDB (PostgreSQL extension) | SQL familiarity, excellent time-series queries, compresses OHLCV data efficiently |
| **Cache / state** | Redis | Real-time quote cache, session state, pub/sub for live dashboard updates |
| **Object store** | S3-compatible (MinIO locally, AWS S3 in prod) | Raw event archive, model artefacts, backtest datasets |
| **Vector store** | pgvector or Qdrant | Semantic search over news and filings for RAG |
| **Broker API** | Alpaca (paper trading first) | Commission-free, well-documented REST + WebSocket API, paper trading environment |
| **Auth** | OAuth 2.0 + JWT | Industry-standard; supports both human users and service-to-service |
| **Observability** | OpenTelemetry → Grafana + Loki | Traces, metrics, and logs in one stack |

---

## Phased Roadmap

### Phase 1 — Foundation (Weeks 1–4)
- [ ] Repository cleanup: update `mix.exs` dependencies to current versions
- [ ] Replace defunct Google Finance endpoint with Alpaca / Polygon market data
- [ ] Set up TimescaleDB schema for OHLCV and events
- [ ] Basic ingestion pipeline: market data + StockTwits (already partially coded)
- [ ] REST API skeleton (Phoenix) with authentication
- [ ] Simple watchlist and price-alert feature

### Phase 2 — Scanning & Ideas (Weeks 5–10)
- [ ] Scanner engine with built-in technical indicators (SMA crossover, RSI, VWAP)
- [ ] News feed integration (Benzinga or NewsAPI)
- [ ] Reddit / X sentiment ingestion
- [ ] Python AI microservice with LLM integration (GPT-4o or Claude)
- [ ] Idea generation: structured trade thesis output
- [ ] Chat-style conversational interface (basic)

### Phase 3 — Execution & Portfolio (Weeks 11–16)
- [ ] Paper trading integration with Alpaca
- [ ] Trade approval workflow (user must explicitly confirm)
- [ ] Portfolio service with real-time P&L
- [ ] Risk controls and position-sizing rules
- [ ] Web dashboard (React or LiveView)

### Phase 4 — Scale & Intelligence (Ongoing)
- [ ] Backtesting engine
- [ ] RAG over historical news and SEC filings
- [ ] Fine-tuning / evaluation pipeline for the LLM layer
- [ ] Alternative data sources (options flow, insider transactions)
- [ ] Live trading (real money, with all risk controls in place)
- [ ] Mobile app

---

## Open Questions & Decisions Needed

1. **Human-in-the-loop vs. automation** — Should StockBoy ever execute trades fully autonomously, or always require explicit human approval? (Recommended: always require approval for real money, at least initially.)
2. **LLM provider** — Cloud API (OpenAI / Anthropic) vs. self-hosted open-source model (Llama 3, Mistral)? Trade-offs: cost, latency, data privacy.
3. **Regulatory & compliance** — Providing investment advice (even via an AI) may trigger SEC/FINRA requirements depending on jurisdiction. Legal review needed before any public-facing deployment.
4. **Data costs** — Real-time institutional-quality data feeds can be expensive. Need to evaluate free/cheap alternatives for the MVP and budget for production data licences.
5. **Elixir vs. polyglot** — Keep all services in Elixir for operational simplicity, or introduce a Python service specifically for the AI/ML layer? Recommended: Python sidecar for LLM calls, Elixir for everything else.
6. **Persistence strategy** — CouchDB was used in the original prototype. TimescaleDB is proposed here for time-series data. Decide whether CouchDB has a continued role (e.g., for document storage of trade theses) or whether it should be replaced entirely.

---

## Original Prototype Notes

The original code in `lib/stock_boy/data_boy.ex` attempted to:
- Fetch quote data from the (now-defunct) `google.com/finance/info` endpoint
- Pull social commentary from the StockTwits streaming API
- Persist raw JSON blobs into CouchDB

These ideas are sound — the architecture above is a modern, scalable evolution of the same concept.

