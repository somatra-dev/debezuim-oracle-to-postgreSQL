#!/bin/bash

# Set consistent password
PASSWORD="password123"

# Set the IP address to include in SANs
IP_ADDRESS="202.178.125.77"

echo "Generating certificates with password: $PASSWORD"

# Create secrets directory if it doesn't exist
mkdir -p secrets

# Generate CA
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -genkeypair \
  -alias ca \
  -dname "CN=ca.cstad.edu.kh, OU=Engineering, O=Company, L=City, ST=State, C=US" \
  -keystore secrets/ca.keystore.jks \
  -keypass $PASSWORD \
  -storepass $PASSWORD \
  -keyalg RSA \
  -keysize 4096 \
  -ext bc:c \
  -validity 365

# Export CA cert
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -exportcert \
  -alias ca \
  -keystore secrets/ca.keystore.jks \
  -storepass $PASSWORD \
  -file secrets/ca.crt \
  -rfc

# Generate server keystore with multiple DNS names and IP address
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -genkeypair \
  -alias server \
  -dname "CN=kafka-kraft, OU=Engineering, O=Company, L=City, ST=State, C=US" \
  -ext "SAN=DNS:kafka-1,DNS:kafka-2,DNS:kafka-3,DNS:schema-registry,DNS:kafka-ui,DNS:debezium-kafka-connect,DNS:localhost,DNS:kafka-kraft.cstad.edu.kh,IP:${IP_ADDRESS}" \
  -keystore secrets/kafka.server.keystore.jks \
  -keypass $PASSWORD \
  -storepass $PASSWORD \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365

# Create server truststore
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -keystore secrets/kafka.server.truststore.jks \
  -alias ca \
  -importcert \
  -file secrets/ca.crt \
  -storepass $PASSWORD \
  -keypass $PASSWORD \
  -noprompt

# Sign server certificate with CA
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -keystore secrets/kafka.server.keystore.jks \
  -alias server \
  -certreq \
  -file secrets/server.csr \
  -storepass $PASSWORD \
  -keypass $PASSWORD

/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -keystore secrets/ca.keystore.jks \
  -alias ca \
  -gencert \
  -infile secrets/server.csr \
  -outfile secrets/server.crt \
  -ext "SAN=DNS:kafka-1,DNS:kafka-2,DNS:kafka-3,DNS:schema-registry,DNS:kafka-ui,DNS:debezium-kafka-connect,DNS:localhost,DNS:kafka-kraft.cstad.edu.kh,IP:${IP_ADDRESS}" \
  -storepass $PASSWORD \
  -keypass $PASSWORD \
  -rfc

# Import CA and signed certificate into server keystore
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -keystore secrets/kafka.server.keystore.jks \
  -alias ca \
  -importcert \
  -file secrets/ca.crt \
  -storepass $PASSWORD \
  -keypass $PASSWORD \
  -noprompt

/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -keystore secrets/kafka.server.keystore.jks \
  -alias server \
  -importcert \
  -file secrets/server.crt \
  -storepass $PASSWORD \
  -keypass $PASSWORD \
  -noprompt

# Clean up temporary files
rm secrets/*.csr secrets/server.crt 2>/dev/null || true

echo "Certificate generation completed successfully. Files created in secrets/:"
ls -l secrets/

# Verify the keystore content
echo -e "\nVerifying keystore content:"
/opt/graalvm-jdk-21/graalvm-jdk-21.0.9+7.1/bin/keytool -list -v -keystore secrets/kafka.server.keystore.jks -storepass $PASSWORD