// Endpoint enrichment table for the asset-enrichment solution.
// Keyed on hostname. Empty riskFactors ("[]") is converted to null.
// Run through the sentinelone-powerquery LRQ runner. Persists as {{ENDPOINT_TABLE}}.
| datasource assets from 'surface/endpoint'
| filter name = *
| filter agentUuid = *
| columns hostname=name, device_os=os, device_ip=agentLastReportedIp,
          device_agentuuid=agentUuid, device_lastuser=agentLastLoggedInUser,
          device_site=s1SiteName, device_criticality=assetCriticality, _rf=riskFactors
| let device_riskfactors = (_rf == '[]' ? null : _rf)
| columns hostname, device_os, device_ip, device_agentuuid, device_lastuser,
          device_site, device_criticality, device_riskfactors
| limit 2000
| savelookup '{{ENDPOINT_TABLE}}'
