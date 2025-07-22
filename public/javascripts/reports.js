// Initialize datepickers
$(document).ready(function() {
  $('.datepicker').datepicker({
    dateFormat: 'yy-mm-dd',
    changeMonth: true,
    changeYear: true
  });
});

// Initialize charts
function initializeCharts() {
  // SLA Chart
  if (document.getElementById('sla-chart')) {
    const slaChart = new Chart(document.getElementById('sla-chart'), {
      type: 'bar',
      data: {
        labels: [],
        datasets: []
      },
      options: {
        responsive: true,
        title: {
          display: true,
          text: 'SLA Statistics'
        },
        scales: {
          yAxes: [{
            ticks: {
              beginAtZero: true
            }
          }]
        }
      }
    });

    // Update chart data when stats are loaded
    function updateSlaChart(stats) {
      slaChart.data.labels = Object.keys(stats).map(id => IssueStatus.find(id).name);
      slaChart.data.datasets = [
        {
          label: 'Count',
          data: Object.values(stats).map(d => d.count),
          backgroundColor: 'rgba(75, 192, 192, 0.2)',
          borderColor: 'rgb(75, 192, 192)',
          borderWidth: 1
        },
        {
          label: 'Avg Response Time',
          data: Object.values(stats).map(d => d.avg_response_time),
          backgroundColor: 'rgba(255, 99, 132, 0.2)',
          borderColor: 'rgb(255, 99, 132)',
          borderWidth: 1
        }
      ];
      slaChart.update();
    }
  }

  // Queue Wait Time Chart
  if (document.getElementById('queue-wait-chart')) {
    const queueChart = new Chart(document.getElementById('queue-wait-chart'), {
      type: 'line',
      data: {
        labels: [],
        datasets: []
      },
      options: {
        responsive: true,
        title: {
          display: true,
          text: 'Queue Wait Time'
        }
      }
    });

    // Update chart data when stats are loaded
    function updateQueueChart(stats) {
      queueChart.data.labels = Object.keys(stats);
      queueChart.data.datasets = [{
        label: 'Average Wait Time',
        data: Object.values(stats),
        borderColor: 'rgb(75, 192, 192)',
        fill: false
      }];
      queueChart.update();
    }
  }

  // Burn Down Chart
  if (document.getElementById('burn-down-chart')) {
    const burnDownChart = new Chart(document.getElementById('burn-down-chart'), {
      type: 'line',
      data: {
        labels: [],
        datasets: []
      },
      options: {
        responsive: true,
        title: {
          display: true,
          text: 'Burn Down'
        }
      }
    });

    // Update chart data when stats are loaded
    function updateBurnDownChart(data) {
      burnDownChart.data.labels = Object.keys(data);
      burnDownChart.data.datasets = [{
        label: 'Remaining Issues',
        data: Object.values(data),
        borderColor: 'rgb(75, 192, 192)',
        fill: false
      }];
      burnDownChart.update();
    }
  }
}

// Initialize charts when page loads
$(document).ready(function() {
  initializeCharts();
});
