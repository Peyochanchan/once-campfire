redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379")

Resque.redis = redis_url
