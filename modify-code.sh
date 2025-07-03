#!/bin/bash

# Allows --force flag to actually force
sed -i -e 's/if percent \> 20.0 {/if percent \> 20.0 \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if syncMode != NoSync {/if syncMode != NoSync \&\& !opt.Force {/g' ./cmd/metadb/dsync/sync.go


# Allows derived table git repo to be customized via ENV variable.
sed -i -e 's/url :\= \"https:\/\/github.com\/folio-org\/folio-analytics.git\"/url :\= os.Getenv("DERIVED_TABLES_GIT_REPO")/g' ./cmd/metadb/server/server.go
sed -i -e 's/ref :\= util.GetFolioVersion()/ref :\= os.Getenv("DERIVED_TABLES_GIT_REFS")/g' ./cmd/metadb/server/server.go

# HOTFIX: Changes library versions to address CVE-2025-21613, CVE-2024-45337, GHSA-9763-4f94-gfch, CVE-2025-21614, CVE-2025-22869, CVE-2023-45288, CVE-2025-22870, CVE-2025-22872

go env -w GOTOOLCHAIN=go1.24.4+auto
go get github.com/go-git/go-git/v5@v5.13.0
go get golang.org/x/crypto@v0.35.0
go get github.com/cloudflare/circl@v1.3.7
go get golang.org/x/net@v0.38.0
