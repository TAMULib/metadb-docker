#!/bin/bash

# Allows --force flag to actually force
sed -i -e 's/if !opt.ForceAll {/if !opt.ForceAll \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if opt.ForceAll {/if opt.ForceAll || opt.Force {/g' ./cmd/metadb/dsync/sync.go

# Allows derived table git repo to be customized via ENV variable.
sed -i -e 's/url :\= \"https:\/\/github.com\/folio-org\/folio-analytics.git\"/url :\= os.Getenv("DERIVED_TABLES_GIT_REPO")/g' ./cmd/metadb/server/server.go
sed -i -e 's/ref, err \= cat.GetConfig(\"external_sql_folio\")/ref \= os.Getenv("DERIVED_TABLES_GIT_REFS")/g' ./cmd/metadb/server/server.go

# Removes manual prompt from endsync process
sed -i -e 's/if !opt.Force \&\& !opt.ForceAll {/if true == false {/g' ./cmd/metadb/dsync/endsync.go

# HOTFIXES
go env -w GOTOOLCHAIN=go1.26.6+auto
go get github.com/go-git/go-git/v5@v5.19.2
go get github.com/go-git/go-billy/v5@v5.9.0
go get github.com/jackc/pgx/v5@v5.9.0
go get golang.org/x/crypto@v0.55.0
go get github.com/cloudflare/circl@v1.6.1
go get golang.org/x/net@v0.56.0
