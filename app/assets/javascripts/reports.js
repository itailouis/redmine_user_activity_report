// Reports JavaScript functionality
$(document).ready(function() {
  // Initialize any report-specific functionality here
  console.log('Reports JavaScript initialized');
  
  // Check if we're on a page that needs chart functionality
  if (typeof chartData !== 'undefined') {
    initializeReportCharts();
  }
  
  // Initialize any date pickers
  $('.date-picker').datepicker({
    dateFormat: 'yy-mm-dd',
    showButtonPanel: true,
    changeMonth: true,
    changeYear: true
  });
  
  // Handle report form submissions
  $('.report-form').on('submit', function(e) {
    // Add any form validation or processing here
    console.log('Report form submitted');
  });
  
  // Handle tab switching if using tabs in reports
  $('.report-tabs a').on('click', function(e) {
    e.preventDefault();
    $(this).tab('show');
  });
});

// Initialize charts for reports
function initializeReportCharts() {
  // Check if Chart.js is available
  if (typeof Chart === 'undefined') {
    console.error('Chart.js is required but not loaded');
    return;
  }
  
  // Initialize any report charts here
  if ($('#issues-over-time-chart').length) {
    initializeIssuesOverTimeChart();
  }
  
  if ($('#priority-breakdown-chart').length) {
    initializePriorityBreakdownChart();
  }
  
  if ($('#status-breakdown-chart').length) {
    initializeStatusBreakdownChart();
  }
}

function initializeIssuesOverTimeChart() {
  const ctx = document.getElementById('issues-over-time-chart').getContext('2d');
  new Chart(ctx, {
    type: 'line',
    data: chartData.issues_over_time || {},
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'bottom',
        },
        tooltip: {
          mode: 'index',
          intersect: false,
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            precision: 0
          }
        }
      }
    }
  });
}

function initializePriorityBreakdownChart() {
  const ctx = document.getElementById('priority-breakdown-chart').getContext('2d');
  new Chart(ctx, {
    type: 'doughnut',
    data: chartData.priority_breakdown || {},
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'bottom',
        }
      }
    }
  });
}

function initializeStatusBreakdownChart() {
  const ctx = document.getElementById('status-breakdown-chart').getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: chartData.status_breakdown || {},
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            precision: 0
          }
        }
      }
    }
  });
}

// Export functions for use in other scripts
window.ReportCharts = {
  initialize: initializeReportCharts,
  issuesOverTime: initializeIssuesOverTimeChart,
  priorityBreakdown: initializePriorityBreakdownChart,
  statusBreakdown: initializeStatusBreakdownChart
};
