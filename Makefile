test:
	rspec

publish-gem:
ifndef RUBY_GEM_API_KEY
	@echo Not to be run locally
	@exit 1
endif
	docker run \
		--volume=$(shell pwd):/src \
		--workdir=/src \
		--env VERSION \
		ruby:2.1.7 \
		sh -c \
			"echo --- > ~/.gem/credentials && \
			echo :rubygems_api_key: $(RUBY_GEM_API_KEY) >> ~/.gem/credentials && \
			chmod 0600 ~/.gem/credentials && \
			gem build fastly-deploy.gemspec && \
			gem push *.gem"
