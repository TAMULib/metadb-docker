#!/bin/bash

# Allows --force flag to actually force
sed -i -e 's/if !opt.ForceAll {/if !opt.ForceAll \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if opt.ForceAll {/if opt.ForceAll || opt.Force {/g' ./cmd/metadb/dsync/sync.go

# Allows derived table git repo to be customized via ENV variable.
sed -i -e 's/url :\= \"https:\/\/github.com\/folio-org\/folio-analytics.git\"/url :\= os.Getenv("DERIVED_TABLES_GIT_REPO")/g' ./cmd/metadb/server/server.go
sed -i -e 's/ref, err \= cat.GetConfig(\"external_sql_folio\")/ref \= os.Getenv("DERIVED_TABLES_GIT_REFS")/g' ./cmd/metadb/server/server.go

# Update dependencies to address CVE-2025-22869, CVE-2025-22870, CVE-2025-22872, and GHSA-2x5j-vhc8-9cwm
go env -w GOTOOLCHAIN=go1.24.6+auto
go get golang.org/x/crypto@v0.35.0
go get golang.org/x/net@v0.38.0
go get github.com/cloudflare/circl@v1.6.1
