#!/bin/bash -xe

OUTPUT_PATH=/app/output
NAMESPACE=${CLIENT_NAMESPACE}
INPUT_PATH=./input/swagger.yaml
SWAGGER_FILE=${SPEC_FILE}

if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE=./input/swagger.json
fi

mkdir -p input
rm -rf input/*
rm -rf $OUTPUT_PATH/*
if [[ $SWAGGER_FILE == http* ]]; then
  curl -o $INPUT_PATH $SWAGGER_FILE
else
  INPUT_PATH=$SWAGGER_FILE
fi


eolConverter "./input/swagger.yaml"

if [ "$ENV_USE_OPENAPI_V3" = "true" ]; then
  if [ "$ENV_USE_DATETIMEOFFSET" = "true" ]; then
    autorest --v3 --use=/app --csharp --output-folder=$OUTPUT_PATH --namespace=$NAMESPACE --input-file=$INPUT_PATH --add-credentials --use-datetimeoffset --debug --version=3.0.6274
  else
    autorest --v3 --use=/app --csharp --output-folder=$OUTPUT_PATH --namespace=$NAMESPACE --input-file=$INPUT_PATH --add-credentials --debug --version=3.0.6274
  fi
else
  if [ "$ENV_USE_DATETIMEOFFSET" = "true" ]; then
    autorest --use=/app --csharp --output-folder=$OUTPUT_PATH --namespace=$NAMESPACE --input-file=$INPUT_PATH --add-credentials --use-datetimeoffset --debug
  else
    autorest --use=/app --csharp --output-folder=$OUTPUT_PATH --namespace=$NAMESPACE --input-file=$INPUT_PATH --add-credentials --debug
  fi
fi

dotnet new classlib -n $NAMESPACE -o $OUTPUT_PATH
cat >NuGet.config <<EOL
<?xml version="1.0" encoding="utf-8"?><configuration><activePackageSource>
<add key="All" value="(Aggregate source)" />
  </activePackageSource>
  <packageRestore>
    <add key="enabled" value="true" />
    <add key="automatic" value="True" />
  </packageRestore>
  <solution>
    <add key="disableSourceControlIntegration" value="true" />
  </solution>
  <packageSources>
    <add key="Klondike" value="https://hk-lib-nuget.agodadev.io/api/odata" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
  </packageSourceCredentials>
</configuration>
EOL

dotnet add $OUTPUT_PATH/$NAMESPACE.csproj package Newtonsoft.Json -v 11.0.2
dotnet add $OUTPUT_PATH/$NAMESPACE.csproj package Microsoft.Rest.ClientRuntime -v 2.3.21
dotnet add $OUTPUT_PATH/$NAMESPACE.csproj package Agoda.Frameworks.Http -v 3.0.75

rm $OUTPUT_PATH/Class1.cs

dotnet pack $OUTPUT_PATH/$NAMESPACE.csproj -p:PackageVersion=$VERSION

if [ "$ENV_SHOULD_PUSH_NUGET" = "false" ]; then
  echo "Nuget is not pushed because ENV_SHOULD_PUSH_NUGET is set to $ENV_SHOULD_PUSH_NUGET"
else
  dotnet nuget push $OUTPUT_PATH/bin/Debug/$NAMESPACE.$VERSION.nupkg -k $NUGET_KEY -s https://hk-lib-nuget.agodadev.io/api/odata
fi
