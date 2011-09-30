Raphael.fn.pyramidChart = function ($, tx, ty, b, h, padding, values, text, colors, min) {
    var paper = this,
        chart = this.set(),
        pyramid = this.set(),
        labels = this.set();
    function sum (values) {
        for (var i = 0, total = 0; i < values.length; i++) {
            total += values[i];
        }
        return total;
    }
    function calculateHeights(b, h, values, total, min) {
        var heights = [],
            adjHeights = [],
            area = 0.5*b*h,
            start = 0,
            remBase = b,
            remHeight = h;
        for (var i = 0, adj = 0, valAdj = 0; i < values.length; i++) {
            var value = values[i];
                areaPlus = area * value / total,
                height = (remHeight - Math.sqrt(remHeight*remHeight - (2*areaPlus*remHeight/remBase))) || remHeight;
            remHeight -= height;
            remBase = remHeight*b/h;
            heights.push(height);
            if (height < min) {
                adj += min - height;
            } else {
                valAdj += height;
            }
        }
        for (var i = 0; i < heights.length; i++) {
            if (heights[i] < min) {
                adjHeights.push(min);
            } else {
                adjHeights.push(heights[i] - adj*(heights[i]/valAdj));
            }
        }
        return adjHeights;
    }
    function trapazoid (tx, ty, b, h, bOffset, trapHeight, params) {
        var b1 = b*(h - bOffset)/h,
            b2 = b*(h - bOffset - trapHeight)/h,
            x1 = tx + 0.5*b1,
            x2 = tx - 0.5*b1,
            y1 = y2 = ty + h - bOffset,
            x3 = tx - 0.5*b2,
            x4 = tx + 0.5*b2,
            y3 = y4 = y1 - trapHeight;
        return paper.path(["M", x1, y1, "L", x2, y2, "L", x3, y3, "L", x4, y4, "z"]).attr(params);
    }
    var total = sum(values),
        heights = calculateHeights(b, h, values, total, min),
        bOffset = 0,
        popup = $('<div class="pyramidchart-popup"></div>')
            .css({position: 'fixed'}).hide().appendTo('body');
    for (var i = 0; i < values.length; i++) {
        var value = values[i],
            trapHeight = heights[i],
            content = value + ' (' + Math.round(value/total*100) + '%)',
            pside = i%2 == 1 ? -1 : 1,
            py = ty + h - bOffset - 0.5*trapHeight,
            px = tx + ((py - ty)/h*b*0.5 + 2)*pside,
            line = paper.path(["M", px, py, "L", px + pside*12, py]).attr({"stroke-width": 1, stroke: '#999'}),
            labelAnchor = pside == 1 ? 'start' : 'end',
            labelText = paper.text(px + pside*16, py, value).attr({font: '10px Helvetica, Arial', fill: '#000', 'text-anchor': labelAnchor}),
            label = paper.set().push(line, labelText),
            color = colors[i],
            hsb = paper.raphael.rgb2hsb(color),
            gcolor = "hsb(" + hsb.h + ", " + hsb.s + ", 0.5)",
            trap = trapazoid(tx, ty, b, h, bOffset, trapHeight, {gradient: "180-" + gcolor + "-" + color, "stroke-width": 0});
        $(trap).data('pyramidchart.popup', {title: text[i], value: value, percent: value/total});
        trap.hover(function () {
          var data = $(this).data('pyramidchart.popup'),
              titleContent = $('<span></span>').text(data.title),
              title = $('<h3 class="pyramidchart-popuptitle"></h3>').append(titleContent),
              value = $('<div class="pyramidchart-popupvalue"></div>').text(data.value),
              percent = $('<div class="pyramidchart-popuppercent"></div>')
                  .text((data.percent * 100).toFixed(2) + '%');
          popup.empty().append(title, value, percent).width('auto').show();
          popup.width(titleContent.outerWidth() + 3);
        }, function () {
            popup.hide();
        }).mousemove(function (event) {
            var top = event.clientY - popup.outerHeight() - 2;
            if (top < 0) {
                top = 0;
            }
            popup.css({left: event.clientX + 2, top: top});
        });
        labels.push(label);
        pyramid.push(trap);
        bOffset += trapHeight;
    }
    for (var i = 0, outside = 0; i < values.length; i++) {
        var bbox = labels[i].getBBox(),
            loverlap = padding - bbox.x,
            roverlap = bbox.x + bbox.width - paper.width + padding;
        if (loverlap > outside) {
            outside = loverlap;
        } else if (roverlap > outside) {
            outside = roverlap;
        }        
    }
    pyramid.scale((b - 2*outside)/b, 1);
    for (var i = 0; i < values.length; i++) {
        var label = labels[i],
            bbox = label.getBBox(),
            bboxx = i%2 == 1 ? bbox.x + bbox.width : bbox.x;
        label.translate(-2*(bboxx - tx)/b*outside, 0);
    }
    chart.push(pyramid, labels);
    return chart;
};

(function (raphael, $) {
    $.fn.pyramidChart = function (opts) {
        var opts = opts == undefined ? {} : opts;
        opts = $.extend($.fn.pyramidChart.defaults, opts);
        var tx = Math.round(opts.width/2),
            ty = opts.padding,
            b = opts.width - 2*opts.padding,
            h = opts.height - 2*opts.padding;
        return this.each(function () {
            var table = $(this),
                values = [],
                text = [],
                colors = opts.colors;
            table.find('tr td:first-child').each(function () {
               text.push($(this).text()); 
            });
            table.find('tr td:last-child').each(function () {
               values.push(parseInt($(this).text(), 0)); 
            });
            raphael.getColor.reset();
            while (colors.length<values.length) {
                colors.push(raphael.getColor(1));
            }
            var wrapper = $('<div class="pyramidchart-wrapper"></div>');
            $('<h2 class="pyramidchart-title"></h2>').text(opts.title)
                .appendTo(wrapper);
            var legend = $('<div class="pyramidchart-legend"></div>');
            $('<h3 class="pyramidchart-legendtitle"></h3>')
                .text(opts.legendTitle).appendTo(legend);
            for (var i = 1; i <= opts.legendColumns; i++) {
                $('<div class="pyramidchart-legendcolumn"></div>')
                    .append('<div class="inner"></div>')
                    .css({
                        width: Math.floor(100/opts.legendColumns) + '%',
                        float: 'left'
                    }).appendTo(legend);
            }
            var columns = legend.find('.pyramidchart-legendcolumn');
            $.each(text, function (index, item) {
                var columnIndex = Math.floor(opts.legendColumns*index/text.length);
                $('<div class="pyramidchart-legenditem"></div>').text(item)
                    .css('border-color', colors[index])
                    .appendTo(columns.eq(columnIndex).find('.inner'));
            });
            $('<div></div>').css({clear: 'left'}).appendTo(legend);
            var container = $('<div class="pyramid-chart"></div>');
            wrapper.append(container, legend);
            table.before(wrapper).hide();
            raphael(container.get(0), opts.width, opts.height)
                .pyramidChart($, tx, ty, b, h, opts.padding, values, text, colors, opts.sectionMin); 
        });
    };
    $.fn.pyramidChart.defaults = {
        colors: [],
        height: 250,
        legendColumns: 2,
        legendTitle: 'Engagement Level',
        padding: 6,
        sectionMin: 5,
        title: 'Engagement Pyramid',
        width: 350
    };
})(Raphael.ninja(), jQuery.noConflict());
