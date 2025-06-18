#!/bin/bash

# Allows --force flag to actually force
sed -i -e 's/if !opt.ForceAll {/if !opt.ForceAll \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if opt.ForceAll {/if opt.ForceAll || opt.Force {/g' ./cmd/metadb/dsync/sync.go

# Allows derived table git repo to be customized via ENV variable.
sed -i -e 's/url :\= \"https:\/\/github.com\/folio-org\/folio-analytics.git\"/url :\= os.Getenv("DERIVED_TABLES_GIT_REPO")/g' ./cmd/metadb/server/server.go
sed -i -e 's/ref, err \= cat.GetConfig(\"external_sql_folio\")/ref \= os.Getenv("DERIVED_TABLES_GIT_TAG")/g' ./cmd/metadb/server/server.go
