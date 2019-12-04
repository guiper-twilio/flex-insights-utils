# flex-insight-utils
Tooling for automating tasks in Flex Insights 

# Usage:
Copy objects (reports or dashboards) between one source workspace and multiple targets

Config File:
```
{
  "source_workspace": "k4wauvc30rsj26tw4phjct3zyi6lif5c",
  "target_workspaces":
  [
    "um1pcv4g18f76igr5cgojw150uic2zm0"
  ],
  "reports_to_copy": [
    129917,
    125816,
    126102
  ],
  "dashboards_to_copy": [
    125820
  ]
}
```
ruby copy_objects.rb --username gpereira@twilio.com -p <password> --config_file sample_copy.json
