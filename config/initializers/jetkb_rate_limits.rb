# frozen_string_literal: true

# Rate limits for agent endpoints. Discriminator hashes the bearer token so
# the cache key never contains the raw secret.
return unless defined?(Rack::Attack)

module JetkbBearerSubject
  def self.discriminator(req)
    header = req.env["HTTP_AUTHORIZATION"]
    return nil unless header.is_a?(String) && header.start_with?("Bearer ")

    token = header.split(" ", 2).last.to_s
    Digest::SHA256.hexdigest(token)[0, 32]
  end
end

# Allow override via env var so integration tests can use a low limit
# without looping 60 times. Production / dev use the spec values.
agent_completion_per_minute = ENV.fetch("AGENT_COMPLETION_PER_MINUTE", "60").to_i
agent_completion_per_day    = ENV.fetch("AGENT_COMPLETION_PER_DAY", "5000").to_i
agent_create_per_hour       = ENV.fetch("AGENT_CREATE_PER_HOUR", "10").to_i
agent_token_create_per_day  = ENV.fetch("AGENT_TOKEN_CREATE_PER_DAY", "20").to_i

# Throttle names are scoped with "jetkb/" so they're unmistakable in logs.

Rack::Attack.throttles.delete("jetkb/agent_completion_per_minute") if Rack::Attack.throttles.key?("jetkb/agent_completion_per_minute")
Rack::Attack.throttle("jetkb/agent_completion_per_minute", limit: agent_completion_per_minute, period: 60.seconds) do |req|
  if req.path.match?(%r{/cards/\d+/agent_completion}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

Rack::Attack.throttles.delete("jetkb/agent_completion_per_day") if Rack::Attack.throttles.key?("jetkb/agent_completion_per_day")
Rack::Attack.throttle("jetkb/agent_completion_per_day", limit: agent_completion_per_day, period: 1.day) do |req|
  if req.path.match?(%r{/cards/\d+/agent_completion}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

Rack::Attack.throttles.delete("jetkb/agent_create_per_hour") if Rack::Attack.throttles.key?("jetkb/agent_create_per_hour")
Rack::Attack.throttle("jetkb/agent_create_per_hour", limit: agent_create_per_hour, period: 1.hour) do |req|
  if req.path.match?(%r{/agents\z}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

Rack::Attack.throttles.delete("jetkb/agent_token_create_per_day") if Rack::Attack.throttles.key?("jetkb/agent_token_create_per_day")
Rack::Attack.throttle("jetkb/agent_token_create_per_day", limit: agent_token_create_per_day, period: 1.day) do |req|
  if req.path.match?(%r{/agents/[^/]+/tokens\z}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

# Throttled responses return 429 with Retry-After.
Rack::Attack.throttled_responder = ->(req) do
  match_data = (req.env["rack.attack.match_data"] || {})
  retry_after = match_data[:period] || 60
  [
    429,
    { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
    [ { error: "rate_limited", retry_after_seconds: retry_after }.to_json ]
  ]
end
