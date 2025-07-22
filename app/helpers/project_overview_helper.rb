module ProjectOverviewHelper
    def health_indicator_class(health)
      "health-indicator health-#{health}"
    end
    
    def format_percentage(value)
      number_with_precision(value, precision: 1) + '%'
    end
    
    def milestone_status_class(status)
      "milestone-status status-#{status}"
    end
    
    def workload_balance_class(balance)
      "balance-#{balance.gsub('-', '_')}"
    end
    
    def format_time_entry(hours)
      if hours < 1
        "#{(hours * 60).round} min"
      else
        "#{hours.round(1)} hrs"
      end
    end
  end