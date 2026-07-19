/*
   Licensed to the Apache Software Foundation (ASF) under one or more
   contributor license agreements.  See the NOTICE file distributed with
   this work for additional information regarding copyright ownership.
   The ASF licenses this file to You under the Apache License, Version 2.0
   (the "License"); you may not use this file except in compliance with
   the License.  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
var showControllersOnly = false;
var seriesFilter = "";
var filtersOnlySampleSeries = true;

/*
 * Add header in statistics table to group metrics by category
 * format
 *
 */
function summaryTableHeader(header) {
    var newRow = header.insertRow(-1);
    newRow.className = "tablesorter-no-sort";
    var cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 1;
    cell.innerHTML = "Requests";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 3;
    cell.innerHTML = "Executions";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 7;
    cell.innerHTML = "Response Times (ms)";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 1;
    cell.innerHTML = "Throughput";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 2;
    cell.innerHTML = "Network (KB/sec)";
    newRow.appendChild(cell);
}

/*
 * Populates the table identified by id parameter with the specified data and
 * format
 *
 */
function createTable(table, info, formatter, defaultSorts, seriesIndex, headerCreator) {
    var tableRef = table[0];

    // Create header and populate it with data.titles array
    var header = tableRef.createTHead();

    // Call callback is available
    if(headerCreator) {
        headerCreator(header);
    }

    var newRow = header.insertRow(-1);
    for (var index = 0; index < info.titles.length; index++) {
        var cell = document.createElement('th');
        cell.innerHTML = info.titles[index];
        newRow.appendChild(cell);
    }

    var tBody;

    // Create overall body if defined
    if(info.overall){
        tBody = document.createElement('tbody');
        tBody.className = "tablesorter-no-sort";
        tableRef.appendChild(tBody);
        var newRow = tBody.insertRow(-1);
        var data = info.overall.data;
        for(var index=0;index < data.length; index++){
            var cell = newRow.insertCell(-1);
            cell.innerHTML = formatter ? formatter(index, data[index]): data[index];
        }
    }

    // Create regular body
    tBody = document.createElement('tbody');
    tableRef.appendChild(tBody);

    var regexp;
    if(seriesFilter) {
        regexp = new RegExp(seriesFilter, 'i');
    }
    // Populate body with data.items array
    for(var index=0; index < info.items.length; index++){
        var item = info.items[index];
        if((!regexp || filtersOnlySampleSeries && !info.supportsControllersDiscrimination || regexp.test(item.data[seriesIndex]))
                &&
                (!showControllersOnly || !info.supportsControllersDiscrimination || item.isController)){
            if(item.data.length > 0) {
                var newRow = tBody.insertRow(-1);
                for(var col=0; col < item.data.length; col++){
                    var cell = newRow.insertCell(-1);
                    cell.innerHTML = formatter ? formatter(col, item.data[col]) : item.data[col];
                }
            }
        }
    }

    // Add support of columns sort
    table.tablesorter({sortList : defaultSorts});
}

$(document).ready(function() {

    // Customize table sorter default options
    $.extend( $.tablesorter.defaults, {
        theme: 'blue',
        cssInfoBlock: "tablesorter-no-sort",
        widthFixed: true,
        widgets: ['zebra']
    });

    var data = {"OkPercent": 100.0, "KoPercent": 0.0};
    var dataset = [
        {
            "label" : "FAIL",
            "data" : data.KoPercent,
            "color" : "#FF6347"
        },
        {
            "label" : "PASS",
            "data" : data.OkPercent,
            "color" : "#9ACD32"
        }];
    $.plot($("#flot-requests-summary"), dataset, {
        series : {
            pie : {
                show : true,
                radius : 1,
                label : {
                    show : true,
                    radius : 3 / 4,
                    formatter : function(label, series) {
                        return '<div style="font-size:8pt;text-align:center;padding:2px;color:white;">'
                            + label
                            + '<br/>'
                            + Math.round10(series.percent, -2)
                            + '%</div>';
                    },
                    background : {
                        opacity : 0.5,
                        color : '#000'
                    }
                }
            }
        },
        legend : {
            show : true
        }
    });

    // Creates APDEX table
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.9937234042553191, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.985, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.9935714285714285, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.9935714285714285, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.9966666666666667, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.9933333333333333, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [1.0, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.9933333333333333, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.994, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.985, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.9992857142857143, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
        switch(index){
            case 0:
                item = item.toFixed(3);
                break;
            case 1:
            case 2:
                item = formatDuration(item);
                break;
        }
        return item;
    }, [[0, 0]], 3);

    // Create statistics table
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 4700, 0, 0.0, 39.182340425531834, 1, 1758, 11.0, 75.0, 113.94999999999982, 584.9899999999998, 59.423716384509376, 3572.295196102215, 59.06567762791903], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 300, 0, 0.0, 127.05666666666664, 43, 1758, 79.0, 238.50000000000017, 340.09999999999957, 823.1600000000008, 4.041764904008083, 3079.8090687100034, 4.128599696867632], "isController": false}, {"data": ["GET /accounts", 700, 0, 0.0, 25.328571428571458, 4, 724, 9.0, 31.0, 52.94999999999993, 691.98, 10.595465140919686, 547.9324770873067, 10.3885224623861], "isController": false}, {"data": ["GET /journal-entries", 700, 0, 0.0, 32.15714285714289, 7, 642, 14.0, 36.89999999999998, 79.0, 526.9300000000001, 10.595465140919686, 141.869553268701, 10.460952399872854], "isController": false}, {"data": ["POST /journal-entries/bulk", 300, 0, 0.0, 28.59666666666666, 5, 678, 10.0, 27.0, 64.89999999999998, 446.5400000000004, 4.041057140547967, 2.391484987472723, 5.210516977491312], "isController": false}, {"data": ["GET /reports/profit-loss", 300, 0, 0.0, 77.36333333333334, 27, 1162, 51.0, 105.90000000000003, 147.69999999999993, 815.9500000000019, 4.038228563736707, 25.992152796473277, 4.065833641809126], "isController": false}, {"data": ["POST /auth/login", 100, 0, 0.0, 21.489999999999995, 5, 121, 12.0, 45.400000000000034, 106.29999999999984, 121.0, 1.7033453703072836, 2.4367320307709344, 0.46908534611977926], "isController": false}, {"data": ["GET /reports/balance-sheet", 300, 0, 0.0, 76.82333333333331, 27, 818, 51.0, 108.90000000000003, 171.24999999999983, 583.8100000000002, 4.040784989830691, 19.975052361838827, 4.076299701655375], "isController": false}, {"data": ["GET /users/me", 1000, 0, 0.0, 17.920999999999985, 2, 846, 5.0, 15.0, 28.949999999999932, 743.8300000000002, 13.084381174192366, 9.442732116922029, 12.828826854383921], "isController": false}, {"data": ["GET /reports/trial-balance", 300, 0, 0.0, 88.11, 28, 1342, 52.0, 110.90000000000003, 168.89999999999998, 976.4600000000005, 4.022849786788962, 42.67599339246922, 4.058206864993161], "isController": false}, {"data": ["GET /periods", 700, 0, 0.0, 6.374285714285716, 1, 788, 4.0, 8.0, 11.0, 33.90000000000009, 10.59658789869662, 11.103651186817846, 10.37927506093038], "isController": false}]}, function(index, item){
        switch(index){
            // Errors pct
            case 3:
                item = item.toFixed(2) + '%';
                break;
            // Mean
            case 4:
            // Mean
            case 7:
            // Median
            case 8:
            // Percentile 1
            case 9:
            // Percentile 2
            case 10:
            // Percentile 3
            case 11:
            // Throughput
            case 12:
            // Kbytes/s
            case 13:
            // Sent Kbytes/s
                item = item.toFixed(2);
                break;
        }
        return item;
    }, [[0, 0]], 0, summaryTableHeader);

    // Create error table
    createTable($("#errorsTable"), {"supportsControllersDiscrimination": false, "titles": ["Type of error", "Number of errors", "% in errors", "% in all samples"], "items": []}, function(index, item){
        switch(index){
            case 2:
            case 3:
                item = item.toFixed(2) + '%';
                break;
        }
        return item;
    }, [[1, 1]]);

        // Create top5 errors by sampler
    createTable($("#top5ErrorsBySamplerTable"), {"supportsControllersDiscrimination": false, "overall": {"data": ["Total", 4700, 0, "", "", "", "", "", "", "", "", "", ""], "isController": false}, "titles": ["Sample", "#Samples", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors"], "items": [{"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}]}, function(index, item){
        return item;
    }, [[0, 0]], 0);

});
