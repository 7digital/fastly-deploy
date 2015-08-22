# fastly-deploy
A tool to assist in the deployment of updated VCL to Fastly. Provides additional verification that the new VCL has taken effect.

## Usage
```
deploy.rb [options]
    -k, --api-key API_KEY            Fastly API Key
    -s, --service-id SERVICE_ID      Service ID
    -v, --vcl-path FILE              VCL Path
    -p, --purge-all                  Purge All
    -h, --help                       Display this screen
```

## Example

```
ruby bin/deploy.rb -k d3cafb4dde4dbeef -s 123456789abcdef -v foo.vcl -p
```

## Deployment Verification

After the new service version has been activated, an optional check can be made against the service URL to ensure that the new VCL has actually taken effect. In order to facilitate this, the VCL file must have the following directives present so that additional logic can be injected before the upload:

