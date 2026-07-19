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
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.9671003539653688, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.7991666666666667, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.9590555555555556, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.9736111111111111, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.9846296296296296, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.9558333333333333, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [0.9961538461538462, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.9635185185185186, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.9919017094017094, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.9453703703703704, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.9922777777777778, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
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
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 104530, 0, 0.0, 146.8393953888821, 1, 5566, 89.0, 282.0, 409.0, 891.9800000000032, 162.35248801732092, 8456.229000097655, 162.84363595147363], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 5400, 0, 0.0, 532.452777777777, 47, 5566, 323.5, 1213.0, 1573.9499999999998, 2945.6599999999926, 8.474283687631626, 6457.371067304644, 8.656348376233087], "isController": false}, {"data": ["GET /accounts", 18000, 0, 0.0, 186.22327777777753, 3, 3664, 106.0, 417.0, 652.0, 1227.9600000000064, 59.716545464196614, 3088.1735010317693, 58.55020668559903], "isController": false}, {"data": ["GET /journal-entries", 18000, 0, 0.0, 139.33033333333285, 8, 3263, 74.0, 307.0, 501.0, 988.9800000000032, 59.71813042439685, 799.6047717274464, 58.959990096743375], "isController": false}, {"data": ["POST /journal-entries/bulk", 5400, 0, 0.0, 86.7270370370372, 5, 4645, 30.0, 110.0, 215.94999999999982, 1538.9799999999996, 8.45868636600736, 5.005824158008261, 10.916124745358296], "isController": false}, {"data": ["GET /reports/profit-loss", 5400, 0, 0.0, 225.0909259259257, 29, 4719, 139.0, 436.90000000000055, 628.9499999999998, 1206.7599999999948, 8.474602870693253, 54.54698000072191, 8.532534726254633], "isController": false}, {"data": ["POST /auth/login", 130, 0, 0.0, 68.89230769230771, 6, 721, 32.5, 167.9, 293.44999999999953, 628.9299999999994, 2.19350048931934, 3.1379645897310433, 0.6040694706914589], "isController": false}, {"data": ["GET /reports/balance-sheet", 5400, 0, 0.0, 209.86796296296302, 30, 4807, 131.0, 405.0, 565.0, 1069.9899999999998, 8.474549671846605, 41.89274456922609, 8.54903301857182], "isController": false}, {"data": ["GET /users/me", 23400, 0, 0.0, 60.70547008546979, 2, 4404, 25.0, 136.0, 270.9500000000007, 611.9900000000016, 36.4841161566946, 26.32984554667706, 35.77153576300916], "isController": false}, {"data": ["GET /reports/trial-balance", 5400, 0, 0.0, 244.73296296296334, 31, 4870, 145.0, 489.8000000000011, 749.9499999999998, 1687.5599999999904, 8.457997428142264, 89.72580670108341, 8.532335296163046], "isController": false}, {"data": ["GET /periods", 18000, 0, 0.0, 58.09922222222238, 1, 2427, 23.0, 124.0, 244.95000000000073, 578.0, 59.71971546873341, 62.577397165967724, 58.49499474134728], "isController": false}]}, function(index, item){
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
    createTable($("#top5ErrorsBySamplerTable"), {"supportsControllersDiscrimination": false, "overall": {"data": ["Total", 104530, 0, "", "", "", "", "", "", "", "", "", ""], "isController": false}, "titles": ["Sample", "#Samples", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors"], "items": [{"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}]}, function(index, item){
        return item;
    }, [[0, 0]], 0);

});
