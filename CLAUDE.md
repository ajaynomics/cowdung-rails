# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Testing Principles

**NEVER skip tests. NEVER mask errors. NEVER avoid failures.**

- It is NEVER appropriate to skip a test case
- It is NEVER okay to avoid errors or mask them
- It is NEVER okay to skip things because we can't get them to work
- If a test fails, FIX THE CODE or FIX THE TEST - don't skip it
- Tests must actually test real behavior, not just assert success
- Every test must provide value and catch real regressions
- A test that passes when the feature is broken is worse than no test
- NEVER use mocking frameworks (mocha, rspec-mocks) - use real objects
- Don't assume things won't work in test - investigate and fix the root cause

### Development Approach for External APIs

1. **Development First**: ALWAYS implement features with rake tasks first, test with real APIs
2. **Test After Confirming**: Once feature works in development, THEN stub responses in tests
3. **WebMock Configuration**: 
   - Always block ALL external calls by default: `WebMock.disable_net_connect!(allow_localhost: true)`
   - Never allow real API calls in tests (no `allow: "api.openai.com"` etc.)
4. **Stubbing Strategy**:
   - WebMock HTTP stubbing is often the cleanest approach for external APIs
   - Keep stubs simple, readable, and focused on the specific test needs
5. **System Tests**: WebMock is appropriate since they run in separate processes
6. **Test Philosophy**: Tests should be human readable and follow Rails Omakase principles

## Project Overview

This is a Rails 8.0.2 application called CowdungRails using modern Rails conventions and tooling:
- Ruby 3.3.4
- SQLite3 database (consider PostgreSQL for production use)
- Vite for frontend bundling with Tailwind CSS 4
- Hotwire (Turbo + Stimulus) for interactive features
- Solid Queue/Cache/Cable for background jobs, caching, and WebSockets
- Kamal for Docker-based deployment

## Development Commands

```bash
# Initial setup
bin/setup

# Start development servers (Rails + Vite)
bin/dev

# Run tests
bin/rails test              # Run all tests
bin/rails test:models       # Run model tests only
bin/rails test test/models/user_test.rb  # Run single test file
bin/rails test test/models/user_test.rb:15  # Run specific test line
bin/rails test:all          # Run entire test suite including system tests

# Code quality
bin/rubocop                 # Run linter (ALWAYS run before completing tasks)
bin/rubocop -a             # Auto-fix violations

# Database
bin/rails db:migrate       # Run migrations
bin/rails db:seed          # Load seed data
bin/rails db:prepare       # Setup database from scratch

# Rails console
bin/rails console          # Interactive console
bin/rails c                # Shorthand

# Background jobs (Solid Queue)
bin/jobs                   # Start job worker in development

# Debugging
bin/rails routes            # Show all routes
bin/rails routes -g users   # Grep routes

# AI/Roast Debugging (rake tasks for real API testing)
bin/rake roast:debug_greeting      # Test greeting workflow with real API
bin/rake roast:debug_example       # Test example workflow (INPUT="your text")
bin/rake roast:debug_raix         # Test Raix configuration directly
```

## Architecture & Structure

### Frontend
- **Vite**: Modern bundling with HMR at `app/frontend/`
  - Entry points: `app/frontend/entrypoints/`
  - Stimulus controllers: `app/frontend/javascript/controllers/`
  - Stylesheets: `app/frontend/stylesheets/`
- **Tailwind CSS 4**: Using the new Vite plugin approach
- **Hotwire**: Turbo for navigation, Stimulus for JavaScript behavior

### Backend
- **Models**: Follow Active Record pattern with business logic
- **Controllers**: RESTful only - create new controllers rather than non-RESTful actions
- **Jobs**: Use for complex operations (NOT service objects)
- **Authentication**: Devise gem included but not configured
- **Authorization**: CanCanCan gem included but not configured

### AI Integration Architecture
- **Raix**: Ruby AI eXtensions for OpenAI client management
- **Roast**: Workflow orchestration for multi-step AI processes
- **Configuration**: OpenAI credentials in `config/credentials.yml.enc` or ENV vars
- **Workflows**: Located in `app/workflows/` with `workflow.yml` and step directories

Current AI features:
- Audio recording interface at `/audio` with 10-second recording/playback
- Greeting workflow at `/pages/greeting` demonstrating Roast integration
- Example workflow job `RunExampleWorkflowJob` for background AI processing

### Testing
- **Framework**: Minitest ONLY (never RSpec or Mocha)
- **Structure**: Follows Rails Omakase principles
  - Don't test Rails framework features
  - Test behavior, not implementation
  - One failure test is enough
  - Use real-world fixtures
- **Test Helper**: Keep under 25 lines (currently 15)
- **WebMock**: Blocks all HTTP except localhost

## Important Project-Specific Notes

1. **No Service Objects**: Use Jobs for complex operations (e.g., TranscriptionJob pattern)
2. **RESTful Routes Only**: Always use RESTful controllers, never custom routes
3. **Code Style**: Follows rubocop-rails-omakase without custom overrides
4. **Browser Support**: Modern browsers only (Chrome/Edge 123+, Firefox 122+, Safari 17.2+)
5. **Background Processing**: Solid Queue runs in Puma process in development
6. **AI Workflow Testing**: Use rake tasks for real API testing, WebMock stubs in tests

## Current Setup Status

### Configured and Ready:
- Rails application structure
- Vite + Tailwind CSS frontend pipeline
- Hotwire (Turbo + Stimulus)
- Testing framework (Minitest + WebMock)
- Code linting (RuboCop)
- Background jobs (Solid Queue)
- Deployment (Kamal + Docker)
- AI integration (Raix + Roast)
- Audio recording with MediaRecorder API

### Gems Included but Not Configured:
- Devise (authentication)
- CanCanCan (authorization)
- dotenv-rails (environment variables)

### Current Routes:
- `/` - Welcome page
- `/audio` - Audio recording interface
- `/pages/greeting` - AI greeting demo

### Next Steps for New Features:
1. For authentication: Configure Devise with `rails generate devise:install`
2. For authorization: Set up CanCanCan abilities
3. For API features: Consider adding `rack-cors` if needed
4. For production: Consider switching to PostgreSQL

## Configuration Patterns

### External Services
Use this pattern for all external service configurations:
```ruby
# config/initializers/service_name.rb
Rails.configuration.x.service_name = Rails.application.config_for(:service_name)

# config/service_name.yml
default: &default
  api_key: <%= Rails.application.credentials.dig(:service_name, :api_key) %>

development:
  <<: *default

production:
  <<: *default
```

### API Client Patterns
When building API clients, consider:
- Circuit breakers for fault tolerance
- Exponential backoff retry logic
- Rate limiting (Redis-based)
- Comprehensive error handling
- Request/response middleware
- Metrics tracking

## Debugging Tips

```ruby
# Quick verification in console
User.last                    # Check latest record
Model.pluck(:id, :name)     # Quick data overview

# Check credentials
Rails.application.credentials.dig(:service, :api_key).present?

# Environment config
Rails.configuration.x       # View all custom configs

# Test Raix/OpenAI connection
Raix.configuration.openai_client.present?
```

## Common Pitfalls

1. **YAML Arrays**: Use simple arrays, not hashes with boolean keys
2. **JSON Parsing**: Some APIs wrap JSON in markdown code blocks
3. **External HTTP**: WebMock blocks all except localhost
4. **Credentials**: Always use `rails credentials:edit` for secrets
5. **Roast Workflows**: Must run in temp directory with proper file structure

## Source Control

Never commit:
- CURRENT_PLAN.md or similar planning files
- .env files with actual values (use .env.example)
- Any temporary debugging or personal notes
- PLAN.md (project planning files)

## Deployment

The app is configured for Kamal deployment with:
- Docker containerization
- Thruster for HTTP caching/compression
- SSL via Let's Encrypt proxy
- Persistent SQLite volumes
- Zero-downtime deployments with asset bridging

Use `kamal deploy` after proper server configuration.