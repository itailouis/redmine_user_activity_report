// Initialize charts when the DOM is fully loaded
$(document).ready(function() {
  // Check if Chart.js is loaded
  if (typeof Chart === 'undefined') {
    console.error('Chart.js is not loaded');
    return;
  }

  // Chart.js global configuration
  Chart.defaults.font.family = '\"-apple-system\", \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif';
  Chart.defaults.color = '#333';
  Chart.defaults.borderColor = 'rgba(0, 0, 0, 0.1)';

  // Common chart options
  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          boxWidth: 12,
          padding: 20,
          usePointStyle: true
        }
      },
      tooltip: {
        mode: 'index',
        intersect: false,
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        titleFont: { size: 13 },
        bodyFont: { size: 13 },
        padding: 10,
        displayColors: true,
        callbacks: {
          label: function(context) {
            const label = context.dataset.label || '';
            const value = context.raw || 0;
            return `${label}: ${value}`;
          }
        }
      }
    },
    scales: {
      x: {
        grid: {
          display: false
        }
      },
      y: {
        beginAtZero: true,
        ticks: {
          precision: 0
        },
        grid: {
          borderDash: [3, 3]
        }
      }
    },
    elements: {
      line: {
        tension: 0.3,
        borderWidth: 2
      },
      point: {
        radius: 4,
        hoverRadius: 6,
        borderWidth: 2
      }
    }
  };

  // Initialize charts if data is available
  if (typeof chartData !== 'undefined') {
    // Issues Over Time Chart
    const issuesTimeCtx = document.getElementById('issues-over-time-chart');
    if (issuesTimeCtx && chartData.issues_over_time) {
      const data = chartData.issues_over_time;
      new Chart(issuesTimeCtx, {
        type: 'line',
        data: {
          labels: data.labels,
          datasets: [{
            label: 'Created',
            data: data.created,
            borderColor: 'rgba(54, 162, 235, 1)',
            backgroundColor: 'rgba(54, 162, 235, 0.1)',
            fill: true
          }, {
            label: 'Closed',
            data: data.closed,
            borderColor: 'rgba(75, 192, 192, 1)',
            backgroundColor: 'rgba(75, 192, 192, 0.1)',
            fill: true
          }]
        },
        options: chartOptions
      });
    }

    // Priority Breakdown Chart
    const priorityCtx = document.getElementById('priority-breakdown-chart');
    if (priorityCtx && chartData.priority_breakdown) {
      const data = chartData.priority_breakdown;
      new Chart(priorityCtx, {
        type: 'doughnut',
        data: {
          labels: data.labels,
          datasets: [{
            data: data.data,
            backgroundColor: [
              'rgba(255, 99, 132, 0.7)',
              'rgba(255, 159, 64, 0.7)',
              'rgba(255, 205, 86, 0.7)',
              'rgba(75, 192, 192, 0.7)',
              'rgba(54, 162, 235, 0.7)'
            ]
          }]
        },
        options: {
          ...chartOptions,
          cutout: '65%'
        }
      });
    }

    // Status Breakdown Chart
    const statusCtx = document.getElementById('status-breakdown-chart');
    if (statusCtx && chartData.status_breakdown) {
      const data = chartData.status_breakdown;
      new Chart(statusCtx, {
        type: 'bar',
        data: {
          labels: data.labels,
          datasets: [{
            label: 'Number of Issues',
            data: data.data,
            backgroundColor: 'rgba(54, 162, 235, 0.7)',
            borderColor: 'rgba(54, 162, 235, 1)',
            borderWidth: 1
          }]
        },
        options: chartOptions
      });
    }
  }

  // Add export functionality
  $(document).on('click', '.export-chart-btn', function() {
    const chartId = $(this).data('chart-id');
    const canvas = document.getElementById(chartId);
    if (canvas) {
      const link = document.createElement('a');
      link.download = `${chartId}.png`;
      link.href = canvas.toDataURL('image/png');
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  });
});
