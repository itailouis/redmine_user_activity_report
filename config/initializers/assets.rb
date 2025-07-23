# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('vendor', 'assets', 'javascripts')

# Add plugin assets to the asset pipeline
Rails.application.config.assets.precompile += %w( projects_overview.js reports.js )

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w( 
  projects_overview.js 
  projects_overview.css
  reports.js 
  reports.css
  chartjs/Chart.min.js
)

# Enable the asset pipeline
Rails.application.config.assets.enabled = true
