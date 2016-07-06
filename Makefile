test:
	rspec

publish-gem:
ifndef FASTLY_PROD_API_KEY
	@echo Not to be run locally
	@exit 1
endif
	docker run \
		--volume $(pwd):/app \
		--workdir /app \
		ruby:2.1.7-slim \
		bash -c ' \
		bundle install --gemfile=deploy/Gemfile && \
		ruby deploy/bin/deploy.rb \
			--api-key $(FASTLY_PROD_API_KEY) \
			--service-id R1ALOuONOpB0QFk3ijfwe \
			--vcl-path apollo-media-delivery.vcl'
