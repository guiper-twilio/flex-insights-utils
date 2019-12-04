# flex-insight-utils
Tooling for automating tasks in Flex Insights 

# Installation
1. Install rvm https://rvm.io/rvm/install - ```curl -sSL https://get.rvm.io | bash -s stable --ruby```
2. Install ruby 2.6.3 - ```rvm install 2.6.3```
3. Install bundler - ```gem install bundler```
4. On the project folder, run ```bundle install --path vendor/bundle``` to install all dependencies
5. To execute, ensure you execute within the bundle context ```bundle exec ruby file.rb``` to load the installed gemset

# Usage:
Copy objects (reports or dashboards, with all the dependencies) between one source workspace and multiple targets without admin permissions (editor role is required)

Prepare a JSON config file:
config-file.json:
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

```bundle exec ruby copy_objects.rb --username gpereira@twilio.com -p password --config_file config_file.json```

Current Limitations:
- Metrics and Report folders are not preserved - On target Workspaces copied objects have no folders associated. Can be easily fixed later is adoption / usage justifies it. 
- Element values must exist in all the target workspaces. For example, if we have a report/metric filtering a specific Queue (queue_xyz), this queue value must exist in all the target workspaces, otherwise the script fails. This cannot be fixed in the future.
