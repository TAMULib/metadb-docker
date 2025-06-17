#!/bin/bash

sed -i -e 's/if percent \> 20.0 {/if percent \> 20.0 \&\& !opt.Force {/g' ./cmd/metadb/dsync/endsync.go
sed -i -e 's/if syncMode != NoSync {/if syncMode != NoSync \&\& !opt.Force {/g' ./cmd/metadb/dsync/sync.go
