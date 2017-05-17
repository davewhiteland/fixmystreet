$(function(){

    Chart.defaults.global.defaultFontFamily = "'MuseoSans', 'Helmet', 'Freesans', sans-serif";
    Chart.defaults.global.defaultFontSize = 16;

    var setUpLabelsForChart = function(chart){
        var $parent = $(chart.chart.canvas).parent();
        var xGutterInPixels = 30;

        $.each(chart.config.data.datasets, function(datasetIndex, dataset){
            var $label = $('.label[data-datasetIndex="' + datasetIndex + '"]', $parent);

            if($label.length === 0) {
                var datasetColor = dataset.borderColor;
                var datasetLabel = dataset.label;
                var latestValue = dataset.data[ dataset.data.length - 1 ];

                $label = $('<span>').addClass('label').appendTo($parent);
                $label.attr('data-datasetIndex', datasetIndex);
                $('<strong>').text(latestValue).css('color', datasetColor).appendTo($label);
                $('<span>').text(datasetLabel).appendTo($label);
            }

            var latestPoint = chart.getDatasetMeta(datasetIndex).data[ dataset.data.length - 1 ];
            $label.css({
                top: latestPoint._model.y,
                left: latestPoint._model.x + xGutterInPixels
            });
        });
    };

    // Returns an array `numberOfPoints` long, where the final item
    // is `radius`, and all the other items are 0.
    var pointRadiusFinalDot = function(numberOfPoints, radius){
        var pointRadius = [];
        for (var i=1; i < numberOfPoints; i++) {
            pointRadius.push(0);
        }
        pointRadius.push(radius);
        return pointRadius;
    };

    var makeSparkline = function makeSparkline($el, valuesStr, color, title){
        var values = [];
        var labels = [];
        $.each(valuesStr.split(' '), function(key, value){
            values.push(Number(value));
            labels.push('');
        });
        var spread = Math.max.apply(null, values) - Math.min.apply(null, values);

        return new Chart($el, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: title,
                    data: values,
                    fill: false,
                    borderWidth: 3,
                    pointRadius: pointRadiusFinalDot(7, 4),
                    pointBackgroundColor: color,
                    pointHitRadius: 0,
                    pointBorderWidth: 0,
                    borderColor: color,
                    lineTension: 0
                }]
            },
            options: {
                responsive: true,
                animation: {
                    duration: 0,
                    onComplete: function(){
                        setUpLabelsForChart(this);
                    }
                },
                layout: {
                    padding: {
                        top: 0,
                        right: 5,
                        bottom: 0,
                        left: 2
                    }
                },
                legend: {
                    display: false
                },
                tooltips: {
                    enabled: false
                },
                scales: {
                    xAxes: [{
                        type: "category",
                        display: false
                    }],
                    yAxes: [{
                        type: "linear",
                        display: false,
                        ticks: {
                            min: Math.min.apply(null, values) - (spread * 0.3),
                            max: Math.max.apply(null, values) + (spread * 0.3)
                        }
                    }]
                }
            }
        });
    };

    $('.labelled-sparkline canvas').each(function(){
        makeSparkline(
            $(this),
            $(this).data('values'),
            $(this).data('color'),
            $(this).data('title')
        );
    });

    window.chartAllReports = new Chart($('#chart-all-reports'), {
        type: 'line',
        data: {
            labels: [
                '2008-12-31', '2009-12-31', '2010-12-31', '2011-12-31', '2012-12-31',
                '2013-12-31', '2014-12-31', '2015-12-31', '2016-12-31', '2017-05-23'
            ],
            datasets: [{
                label: 'problems reported',
                data: [
                    200, 400, 800, 1600, 3200,
                    6400, 12800, 25600, 51200, 102400
                ],
                fill: false,
                borderWidth: 3,
                pointRadius: pointRadiusFinalDot(10, 4),
                pointBackgroundColor: '#F4A140',
                pointHitRadius: 0,
                pointBorderWidth: 0,
                borderColor: '#F4A140'
            }, {
                label: 'reports marked as fixed',
                data: [
                    50, 100, 200, 400, 800,
                    1600, 3200, 6400, 12800, 25600
                ],
                fill: false,
                borderWidth: 3,
                pointRadius: pointRadiusFinalDot(10, 4),
                pointBackgroundColor: '#62B356',
                pointHitRadius: 0,
                pointBorderWidth: 0,
                borderColor: '#62B356'
            }]
        },
        options: {
            responsive: true,
            animation: {
                duration: 0,
                onComplete: function(){
                    setUpLabelsForChart(this);
                }
            },
            legend: {
                display: false
            },
            tooltips: {
                enabled: false
            },
            scales: {
                xAxes: [{
                    type: 'time',
                    time: {
                        displayFormats: {
                            year: 'YYYY'
                        },
                        unit: 'year',
                        round: 'year'
                    },
                    gridLines: {
                        display: false
                    }
                }],
                yAxes: [{
                    type: "linear",
                    ticks: {
                        display: false
                    },
                    gridLines: {
                        drawBorder: false
                    }
                }]
            },
            onResize: function(chart, size){
                setUpLabelsForChart(chart);
            }
        }
    });
});