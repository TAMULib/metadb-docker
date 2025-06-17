#!/bin/bash

sed -i -e 's/if !opt.ForceAll {/if !opt.ForceAll \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if opt.ForceAll {/if opt.ForceAll || opt.Force {/g' ./cmd/metadb/dsync/sync.go
