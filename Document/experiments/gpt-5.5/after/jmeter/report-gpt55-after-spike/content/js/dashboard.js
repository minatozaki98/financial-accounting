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
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.7036666666666667, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.25733333333333336, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.5560714285714285, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.7227857142857143, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.8508333333333333, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.7876666666666666, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [0.6, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.8105, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.7749, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.6748333333333333, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.7965714285714286, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
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
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 46500, 0, 0.0, 737.1797634408588, 1, 11281, 364.0, 1702.0, 2481.850000000002, 4225.980000000003, 265.0373047131042, 16100.133733184024, 265.5145065621669], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 3000, 0, 0.0, 2292.9919999999943, 27, 11281, 1751.5, 4870.700000000001, 6009.95, 8166.859999999997, 17.647993129048007, 13447.701826861421, 18.0271492314299], "isController": false}, {"data": ["GET /accounts", 7000, 0, 0.0, 1053.4991428571411, 5, 8680, 804.5, 2406.7000000000016, 3080.95, 4625.809999999996, 59.914578928898514, 3098.414577324044, 58.744372309193466], "isController": false}, {"data": ["GET /journal-entries", 7000, 0, 0.0, 667.9511428571439, 13, 6747, 429.5, 1506.9000000000005, 2298.95, 3915.99, 59.21464462753988, 792.8632739142572, 58.46289620941682], "isController": false}, {"data": ["POST /journal-entries/bulk", 3000, 0, 0.0, 381.4310000000002, 5, 3726, 261.0, 869.9000000000001, 1157.5999999999985, 1899.909999999998, 17.804893971856398, 10.536880612250954, 22.984848823467445], "isController": false}, {"data": ["GET /reports/profit-loss", 3000, 0, 0.0, 518.2943333333347, 7, 3935, 334.0, 1236.5000000000005, 1841.0, 2769.8899999999976, 17.649654360935433, 113.602413957935, 17.77030629504339], "isController": false}, {"data": ["POST /auth/login", 500, 0, 0.0, 1026.552, 8, 4859, 479.5, 2773.400000000001, 3407.0, 4660.780000000001, 15.05706628120577, 21.540044973574847, 4.146574893847682], "isController": false}, {"data": ["GET /reports/balance-sheet", 3000, 0, 0.0, 454.54233333333536, 6, 4945, 318.0, 1065.8000000000002, 1485.699999999999, 2112.99, 17.650381248234964, 87.25217761578651, 17.80551155217453], "isController": false}, {"data": ["GET /users/me", 10000, 0, 0.0, 513.6104999999968, 2, 7044, 360.0, 1196.0, 1583.8499999999967, 2663.909999999998, 58.250617456545044, 42.03828740272147, 57.11291008434689], "isController": false}, {"data": ["GET /reports/trial-balance", 3000, 0, 0.0, 834.9540000000018, 11, 6242, 490.5, 2249.600000000002, 3221.5499999999984, 4504.98, 17.641766293641318, 187.15088598420476, 17.79682088020653], "isController": false}, {"data": ["GET /periods", 7000, 0, 0.0, 447.5264285714294, 1, 4081, 298.0, 1100.9000000000005, 1406.9499999999998, 2074.869999999997, 59.70403855175061, 62.56097008401211, 58.47963932363853], "isController": false}]}, function(index, item){
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
