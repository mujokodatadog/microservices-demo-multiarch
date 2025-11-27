export PROJECT_ID="datadog-partner-tech-sandbox"
export LOCATION="us-east1"
export REPOSITORY="joko-repo-multiarch"

# Delete the application
skaffold delete

# Delete GKE cluster
gcloud container clusters delete swagstore --zone=us-central1-a --quiet

# Delete container images from Artifact Registry
for service in adservice cartservice checkoutservice currencyservice emailservice frontend loadgenerator paymentservice productcatalogservice recommendationservice shippingservice; do
    echo "Deleting ${service}..."
    
    # Get all versions and delete them
    gcloud artifacts docker images list \
        ${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${service} \
        --include-tags \
        --format="value(version)" 2>/dev/null | \
    while read -r version; do
        if [ ! -z "$version" ]; then
            gcloud artifacts docker images delete \
                ${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${service}@${version} \
                --quiet 2>/dev/null || \
            gcloud artifacts docker images delete \
                ${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${service}:${version} \
                --quiet 2>/dev/null
        fi
    done
done

# Verify deletion
gcloud artifacts docker images list ${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}

echo "✅ Cleanup complete!"