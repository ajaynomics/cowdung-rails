# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Testing
- **Framework**: Minitest ONLY (never RSpec or Mocha)
- **Structure**: Follows Rails Omakase principles
  - Don't test Rails framework features
  - Test behavior, not implementation
  - One failure test is enough
  - Use real-world fixtures
- **Test Helper**: Keep under 25 lines (currently 15)
- **WebMock**: If used, blocks all HTTP except localhost

## Important Project-Specific Notes

1. **No Service Objects**: Use Jobs for complex operations (e.g., GeocodeLocationJob pattern)
2. **RESTful Routes Only**: Always use RESTful controllers, never custom routes
3. **Code Style**: Follows rubocop-rails-omakase without custom overrides
4. **Browser Support**: Modern browsers only (Chrome/Edge 123+, Firefox 122+, Safari 17.2+)
5. **Background Processing**: Solid Queue runs in Puma process in development

## Current Setup Status

### Configured and Ready:
- Rails application structure
- Vite + Tailwind CSS frontend pipeline
- Hotwire (Turbo + Stimulus)
- Testing framework (Minitest)
- Code linting (RuboCop)
- Background jobs (Solid Queue)
- Deployment (Kamal + Docker)

### Gems Included but Not Configured:
- Devise (authentication)
- CanCanCan (authorization)
- dotenv-rails (environment variables)

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
```

## Common Pitfalls

1. **YAML Arrays**: Use simple arrays, not hashes with boolean keys
2. **JSON Parsing**: Some APIs wrap JSON in markdown code blocks
3. **External HTTP**: WebMock blocks all except localhost
4. **Credentials**: Always use `rails credentials:edit` for secrets

## Source Control

Never commit:
- CURRENT_PLAN.md or similar planning files
- .env files with actual values (use .env.example)
- Any temporary debugging or personal notes

## Deployment

The app is configured for Kamal deployment with:
- Docker containerization
- Thruster for HTTP caching/compression
- SSL via Let's Encrypt proxy
- Persistent SQLite volumes
- Zero-downtime deployments with asset bridging

Use `kamal deploy` after proper server configuration.