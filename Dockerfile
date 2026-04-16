FROM quay.io/keycloak/keycloak:26.2.4

COPY keycloak/realm-export.json /opt/keycloak/data/import/realm.json