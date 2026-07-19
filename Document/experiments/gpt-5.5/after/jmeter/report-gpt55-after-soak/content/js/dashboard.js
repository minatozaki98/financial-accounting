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
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.9954749832583947, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.9518518518518518, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.9936666666666667, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.9971388888888889, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.9993518518518518, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.9996296296296296, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [0.9961538461538462, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.9994444444444445, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.9993376068376069, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.9982407407407408, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.99925, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
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
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 104530, 0, 0.0, 48.30583564526893, 0, 2780, 18.0, 84.0, 143.0, 286.9800000000032, 222.18396228420332, 11572.588071670561, 222.85611209484318], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 5400, 0, 0.0, 210.45500000000044, 23, 2780, 137.0, 481.0, 656.8499999999995, 1120.9399999999987, 11.569313039901274, 8815.77134377571, 11.817872499742904], "isController": false}, {"data": ["GET /accounts", 18000, 0, 0.0, 65.02838888888867, 2, 1555, 31.0, 158.0, 250.95000000000073, 540.9800000000032, 75.25681387735648, 3891.8208778080198, 73.78695423131435], "isController": false}, {"data": ["GET /journal-entries", 18000, 0, 0.0, 53.43500000000008, 6, 1024, 29.0, 113.0, 182.0, 417.0, 75.25649923489226, 1007.6580673921951, 74.30109445944929], "isController": false}, {"data": ["POST /journal-entries/bulk", 5400, 0, 0.0, 29.236666666666732, 4, 945, 18.0, 52.0, 82.0, 225.97999999999956, 11.569288253101748, 6.8466686341598235, 14.930426347688178], "isController": false}, {"data": ["GET /reports/profit-loss", 5400, 0, 0.0, 39.903888888888865, 4, 652, 25.0, 77.0, 134.94999999999982, 300.97999999999956, 11.569635277960488, 74.46822862991951, 11.64872458161842], "isController": false}, {"data": ["POST /auth/login", 130, 0, 0.0, 41.892307692307696, 6, 582, 15.5, 104.50000000000003, 223.0999999999998, 542.3199999999997, 2.1971335857220122, 3.143211517416509, 0.6050699913804759], "isController": false}, {"data": ["GET /reports/balance-sheet", 5400, 0, 0.0, 37.92259259259264, 4, 679, 23.0, 75.0, 124.94999999999982, 287.96999999999935, 11.569932744409472, 57.19433550019605, 11.671621606420885], "isController": false}, {"data": ["GET /users/me", 23400, 0, 0.0, 23.356709401709434, 1, 887, 10.0, 49.0, 95.0, 242.9900000000016, 49.95047645069845, 36.04824423541617, 48.974881207520745], "isController": false}, {"data": ["GET /reports/trial-balance", 5400, 0, 0.0, 48.47703703703721, 6, 906, 31.0, 92.90000000000055, 159.0, 366.9899999999998, 11.569313039901274, 122.73188237543707, 11.670996455291032], "isController": false}, {"data": ["GET /periods", 18000, 0, 0.0, 21.594500000000085, 0, 856, 7.0, 45.0, 95.0, 273.9800000000032, 75.25775782053533, 78.85895912249454, 73.71438583398138], "isController": false}]}, function(index, item){
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
