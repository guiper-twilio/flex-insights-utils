# flex-insight-utils
Tooling for automating tasks in Flex Insights.

First iteration as a set of basic ruby scripts, which passed a basic usage test. No warranties it will work in all the cases. Check limitations bellow.  

If anything is not working open an issue with details, or feel free to create a PR. 

Looking for an owner with more time than me. 

# Installation 
Steps to be double checked
1. Install rvm https://rvm.io/rvm/install - ```curl -sSL https://get.rvm.io | bash -s stable --ruby```
2. Install ruby 2.6.3 - ```rvm install 2.6.3```
3. Install bundler - ```gem install bundler```
4. On the project folder, run ```bundle install --path vendor/bundle``` to install all dependencies
5. To execute, ensure you execute within the bundle context ```bundle exec ruby file.rb``` to load the installed gemset

# Scripts:
## Copy objects between workspaces 
Performs the copy of reports or dashboards ( with all the dependencies around) between one source workspace and multiple targets without admin permissions (editor role is required)

Use cases:
- **Build once deploy many times** -  Some customizations around Flex require specific vizualizations in Flex insights, which might not be included in the out of box solution. This allows Expert Services or any other organization to build their set of custom dashboards, reports and metrics and push to any customer workspace.
- **Dev -> Test -> Prod** - Allows a phased development of new dashboards, reports and metrics. Development can be done in Dev environment shielded from production, and once everybody is happy copied to the production environment. 

### Usage
Prepare a JSON config file:
`config-file.json`:
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

```bundle exec ruby copy_objects.rb --username gpereira@twilio.com -p password --config_file config-file.json```

### Current Limitations:
- Only reports and dashboards currently supported. Can be easily expanded to support metrics or KPI Dashboards
- Metrics and Report folders are not preserved - On target Workspaces copied objects have no folders associated. Can be easily fixed later is adoption / usage justifies it. 
- Element values MUST exist in all the target workspaces. For example, if we have a report/metric filtering a specific Queue (queue_xyz), this queue value must exist in all the target workspaces, otherwise the script fails as the end metric cannot be created or would be different if we skip this filter. This cannot be fixed in the future

