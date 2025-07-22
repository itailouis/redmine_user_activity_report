// Initialize datepickers and charts
document.addEventListener('DOMContentLoaded', function() {
  // Initialize datepickers
  $('.datepicker').datepicker({
    dateFormat: 'yy-mm-dd',
    changeMonth: true,
    changeYear: true
  });

  // Initialize charts if chart data is available
  if (typeof chartData !== 'undefined') {
    initializeCharts();
  }

  // Add event listeners to export buttons
  document.querySelectorAll('.export-chart-btn').forEach(function(button) {
    button.addEventListener('click', function() {
      const chartId = this.getAttribute('data-chart-id');
      exportChart(chartId);
    });
  });
});

// Function to initialize all charts
function initializeCharts() {
  // Issues Over Time Chart
  if (document.getElementById('issues-over-time-chart') && chartData.issues_over_time) {
    const issuesOverTimeData = chartData.issues_over_time;
    const labels = issuesOverTimeData.map(d => d.date);
    const createdData = issuesOverTimeData.map(d => d.created);
    const closedData = issuesOverTimeData.map(d => d.closed);

    new Chart(document.getElementById('issues-over-time-chart'), {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Created Issues',
            data: createdData,
            borderColor: 'rgb(54, 162, 235)',
            backgroundColor: 'rgba(54, 162, 235, 0.1)',
            fill: true
          },
          {
            label: 'Closed Issues',
            data: closedData,
            borderColor: 'rgb(75, 192, 192)',
            backgroundColor: 'rgba(75, 192, 192, 0.1)',
            fill: true
          }
        ]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Count'
            }
          }
        }
      }
    });
  }

  // Burndown Chart
  if (document.getElementById('burndown-chart') && chartData.burndown_data && chartData.burndown_data.length > 0) {
    const burndownData = chartData.burndown_data;
    const labels = burndownData.map(d => d.date);
    const actualData = burndownData.map(d => d.actual);
    const idealData = burndownData.map(d => d.ideal);

    new Chart(document.getElementById('burndown-chart'), {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Actual',
            data: actualData,
            borderColor: 'rgb(255, 99, 132)',
            backgroundColor: 'rgba(255, 99, 132, 0.1)',
            fill: false
          },
          {
            label: 'Ideal',
            data: idealData,
            borderColor: 'rgb(54, 162, 235)',
            backgroundColor: 'rgba(54, 162, 235, 0.1)',
            borderDash: [5, 5],
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Remaining Issues'
            }
          }
        }
      }
    });
  }

  // Workload Distribution Chart
  if (document.getElementById('workload-chart') && chartData.workload_distribution) {
    const workloadData = chartData.workload_distribution;
    const labels = workloadData.map(d => d.name);
    const openIssuesData = workloadData.map(d => d.open_issues);
    const hoursData = workloadData.map(d => d.total_hours);

    new Chart(document.getElementById('workload-chart'), {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Open Issues',
            data: openIssuesData,
            backgroundColor: 'rgba(255, 99, 132, 0.5)',
            borderColor: 'rgb(255, 99, 132)',
            borderWidth: 1,
            yAxisID: 'y'
          },
          {
            label: 'Hours Logged',
            data: hoursData,
            backgroundColor: 'rgba(54, 162, 235, 0.5)',
            borderColor: 'rgb(54, 162, 235)',
            borderWidth: 1,
            yAxisID: 'y1'
          }
        ]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            position: 'left',
            title: {
              display: true,
              text: 'Open Issues'
            }
          },
          y1: {
            beginAtZero: true,
            position: 'right',
            grid: {
              drawOnChartArea: false
            },
            title: {
              display: true,
              text: 'Hours'
            }
          }
        }
      }
    });
  }

  // Resolution Time Chart
  if (document.getElementById('resolution-time-chart') && chartData.issue_resolution_time) {
    const resolutionTimeData = chartData.issue_resolution_time;
    
    new Chart(document.getElementById('resolution-time-chart'), {
      type: 'bar',
      data: {
        labels: ['Average', 'Median', 'Min', 'Max'],
        datasets: [{
          label: 'Resolution Time (days)',
          data: [
            resolutionTimeData.average,
            resolutionTimeData.median,
            resolutionTimeData.min,
            resolutionTimeData.max
          ],
          backgroundColor: [
            'rgba(75, 192, 192, 0.5)',
            'rgba(54, 162, 235, 0.5)',
            'rgba(255, 206, 86, 0.5)',
            'rgba(255, 99, 132, 0.5)'
          ],
          borderColor: [
            'rgb(75, 192, 192)',
            'rgb(54, 162, 235)',
            'rgb(255, 206, 86)',
            'rgb(255, 99, 132)'
          ],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Days'
            }
          }
        }
      }
    });
  }
}

// Function to export chart as PNG
function exportChart(chartId) {
  const canvas = document.getElementById(chartId);
  if (!canvas) return;
  
  // Create a temporary link element
  const link = document.createElement('a');
  link.download = chartId + '.png';
  
  // Convert canvas to data URL and set as link href
  link.href = canvas.toDataURL('image/png');
  
  // Append link to body, click it, and remove it
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}
