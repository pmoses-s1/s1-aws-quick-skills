// Identity enrichment table for the asset-enrichment solution.
// Keyed on {{USERNAME_KEY}} (samAccountName or principalName).
// Empty riskFactors ("[]") is converted to null so enrichment never writes an empty field.
// Run through the sentinelone-powerquery LRQ runner. Persists as {{IDENTITY_TABLE}}.
| datasource assets from 'surface/identity'
| filter resourceType = 'AD User'
| filter objectSid = *
| columns username={{USERNAME_KEY}}, user_principal=principalName, user_sid=objectSid,
          user_domain=domain, user_dn=distinguishedName, user_groups=memberOf,
          user_privileged=privileged, user_criticality=assetCriticality, _rf=riskFactors
| let user_riskfactors = (_rf == '[]' ? null : _rf)
| columns username, user_principal, user_sid, user_domain, user_dn, user_groups,
          user_privileged, user_criticality, user_riskfactors
| limit 1000
| savelookup '{{IDENTITY_TABLE}}'
