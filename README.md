# fastly-deploy
A tool to assist in the deployment of updated VCL to Fastly. Provides additional verification that the new VCL has taken effect.

## Installation

This app is available via [rubygems](https://rubygems.org/gems/fastly-deploy):

```
gem install fastly-deploy
```

## Usage
```
fastly-deploy [options]
    -k, --api-key API_KEY            Fastly API Key
    -s, --service-id SERVICE_ID      Service ID
    -v, --vcl-path FILE              VCL Path
    -i, --vcl-includes INCLUDES_DIR  Includes Directory (optional)
    -p, --purge-all                  Purge All
    -h, --help                       Display this screen
```

## Example

To deploy a new main VCL (foo.vcl) with includes contained in the 'includes' directory:

```
fastly-deploy --api-key d3cafb4dde4dbeef --service-id 123456789abcdef --vcl-path foo.vcl --vcl-includes includes --purge-all
```

## Versioning

The deployment process clones the current activated version in Fastly, as opposed to the latest/highest numbered version.

## Deployment Verification

After the new service version has been activated, an optional check can be made against the service URL to ensure that the new VCL has actually taken effect. In order to facilitate this, the VCL file must have the following `#7D_DEPLOY` directives present so that additional logic can be injected before the upload:

```
sub vcl_recv {
    #7D_DEPLOY recv
    ...
}

sub vcl_error {
    #7D_DEPLOY error
    ...
}
```

The directives inject code that cause the VCL to emit a synthetic response containing the newly activated service version number when a request is made against `/vcl_version`. After deployment, this URL is polled until the version number matches that of the new deployment.

If the directives are not present, the additional verification check is skipped.

## Testing

Tests can be run against a Fastly account by populating the `FASTLY_SANDBOX_API_KEY` environment variable with a Fastly API key and running `rspec`. As part of the tests, services will be automatically created and deleted by the fixtures. **Do not run the tests using an account shared with production services.**

## Linting

Rubocop linting can be run with `make lint`
