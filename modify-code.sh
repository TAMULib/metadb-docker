#!/bin/bash

# Allows --force flag to actually force
sed -i -e 's/if percent \> 20.0 {/if percent \> 20.0 \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if syncMode != NoSync {/if syncMode != NoSync \&\& !opt.Force {/g' ./cmd/metadb/dsync/sync.go


# Allows derived table git repo to be customized via ENV variable.
sed -i -e 's/url :\= \"https:\/\/github.com\/folio-org\/folio-analytics.git\"/url :\= os.Getenv("DERIVED_TABLES_GIT_REPO")/g' ./cmd/metadb/server/server.go
sed -i -e 's/ref :\= util.GetFolioVersion()/ref :\= os.Getenv("DERIVED_TABLES_GIT_REFS")/g' ./cmd/metadb/server/server.go
