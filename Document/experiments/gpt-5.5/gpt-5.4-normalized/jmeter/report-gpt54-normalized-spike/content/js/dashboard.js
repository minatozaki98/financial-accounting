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
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.6804731182795699, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.21866666666666668, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.4928571428571429, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.6841428571428572, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.8225, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.8186666666666667, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [0.618, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.8111666666666667, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.7516, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.713, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.7751428571428571, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
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
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 46500, 0, 0.0, 788.265505376341, 2, 12808, 425.0, 1771.9000000000015, 2593.9500000000007, 4931.790000000034, 259.18432185676306, 15754.055748013268, 259.65098536200804], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 3000, 0, 0.0, 2572.2523333333343, 20, 12808, 2083.5, 5340.1, 6621.799999999999, 8538.99, 17.36623656287446, 13225.406695552507, 17.739339301529967], "isController": false}, {"data": ["GET /accounts", 7000, 0, 0.0, 1179.4480000000021, 10, 8123, 993.5, 2418.9000000000005, 3041.8499999999995, 4510.869999999997, 49.44166236995077, 2556.819561328851, 48.476004901787675], "isController": false}, {"data": ["GET /journal-entries", 7000, 0, 0.0, 728.4987142857161, 14, 6962, 508.0, 1685.9000000000005, 2256.95, 3757.99, 49.05395935529082, 656.8152702347583, 48.43120401191311], "isController": false}, {"data": ["POST /journal-entries/bulk", 3000, 0, 0.0, 419.5719999999985, 5, 3453, 307.0, 947.9000000000001, 1240.7999999999993, 1877.909999999998, 17.32851985559567, 10.254963898916968, 22.369883799638988], "isController": false}, {"data": ["GET /reports/profit-loss", 3000, 0, 0.0, 437.90499999999946, 3, 4911, 300.0, 1013.9000000000001, 1401.7999999999993, 2410.909999999998, 17.347157090072223, 116.78837986226358, 17.46574117174264], "isController": false}, {"data": ["POST /auth/login", 500, 0, 0.0, 889.4800000000005, 10, 5087, 687.5, 2071.3000000000006, 2589.4999999999995, 4063.7400000000002, 15.045739046701975, 21.52401699604297, 4.143455479658161], "isController": false}, {"data": ["GET /reports/balance-sheet", 3000, 0, 0.0, 437.77333333333394, 3, 4210, 312.0, 1001.0, 1298.9499999999998, 2118.9799999999996, 17.364326727171697, 89.41610823474254, 17.51694288004723], "isController": false}, {"data": ["GET /users/me", 10000, 0, 0.0, 571.1245000000017, 2, 9181, 422.0, 1233.8999999999996, 1655.8499999999967, 3016.959999999999, 56.45316081247389, 40.7410994535334, 55.350560015355256], "isController": false}, {"data": ["GET /reports/trial-balance", 3000, 0, 0.0, 673.1509999999998, 4, 6499, 432.0, 1655.900000000001, 2236.3499999999976, 3691.319999999985, 17.3378334643303, 192.6294251207869, 17.490216766262886], "isController": false}, {"data": ["GET /periods", 7000, 0, 0.0, 502.96757142857115, 3, 4940, 397.0, 1100.0, 1405.0, 2231.8799999999974, 49.24133176699002, 51.59760643162137, 48.23149976786229], "isController": false}]}, function(index, item){
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
    createTable($("#top5ErrorsBySamplerTable"), {"supportsControllersDiscrimination": false, "overall": {"data": ["Total", 46500, 0, "", "", "", "", "", "", "", "", "", ""], "isController": false}, "titles": ["Sample", "#Samples", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors"], "items": [{"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}]}, function(index, item){
        return item;
    }, [[0, 0]], 0);

});
