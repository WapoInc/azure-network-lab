targetScope = 'subscription'

param defaults object
param extra object

output tags object = union(defaults, extra)
