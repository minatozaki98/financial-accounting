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
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.9861236008801301, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.898425925925926, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.9743611111111111, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.9891666666666666, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.9974074074074074, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.9972222222222222, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [0.9769230769230769, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.9968518518518519, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.9960042735042735, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.995462962962963, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.9956388888888889, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
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
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 104530, 0, 0.0, 74.86475652922466, 1, 3414, 11.0, 65.0, 117.0, 284.0, 216.57426054382867, 11286.740362767196, 217.22943991284095], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 5400, 0, 0.0, 289.4907407407412, 21, 3414, 147.0, 731.0, 1042.8999999999996, 1700.8799999999974, 11.286186334936389, 8595.092194034623, 11.528662994476038], "isController": false}, {"data": ["GET /accounts", 18000, 0, 0.0, 124.95650000000089, 3, 2604, 58.0, 303.0, 499.0, 1021.9400000000096, 67.22111639336303, 3476.2638853618546, 65.90820396380516], "isController": false}, {"data": ["GET /journal-entries", 18000, 0, 0.0, 84.00694444444373, 6, 2341, 42.0, 182.0, 315.0, 699.0, 67.2213674319944, 900.070477402417, 66.3679711657679], "isController": false}, {"data": ["POST /journal-entries/bulk", 5400, 0, 0.0, 37.29685185185184, 4, 1317, 18.0, 70.0, 120.0, 381.9499999999989, 11.28769620210829, 6.680023338357055, 14.567025481059664], "isController": false}, {"data": ["GET /reports/profit-loss", 5400, 0, 0.0, 33.404629629629525, 3, 1557, 14.0, 62.0, 122.94999999999982, 362.96999999999935, 11.287979347178528, 75.99543908149295, 11.365143268497132], "isController": false}, {"data": ["POST /auth/login", 130, 0, 0.0, 95.26923076923079, 6, 1411, 23.5, 223.9000000000003, 519.5999999999988, 1367.9099999999996, 2.206643694939996, 3.156750340544532, 0.607688986301835], "isController": false}, {"data": ["GET /reports/balance-sheet", 5400, 0, 0.0, 34.957222222222136, 3, 1546, 13.0, 64.0, 128.0, 388.91999999999825, 11.287672607326954, 58.12490005706545, 11.386880667352287], "isController": false}, {"data": ["GET /users/me", 23400, 0, 0.0, 40.77683760683755, 1, 1259, 15.0, 87.0, 185.0, 450.9900000000016, 48.69420455727812, 35.141618327957545, 47.74314587451878], "isController": false}, {"data": ["GET /reports/trial-balance", 5400, 0, 0.0, 38.4011111111111, 3, 1882, 15.0, 69.0, 139.0, 471.9899999999998, 11.28816811845051, 125.41551629258932, 11.38738053355408], "isController": false}, {"data": ["GET /periods", 18000, 0, 0.0, 42.02972222222206, 1, 1431, 14.0, 95.0, 193.0, 469.0, 67.22237160527024, 70.43906712153806, 65.84378781258404], "isController": false}]}, function(index, item){
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
