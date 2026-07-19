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
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.554247311827957, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.3353333333333333, 500, 1500, "GET /reports/account-ledger"], "isController": false}, {"data": [0.5322142857142858, 500, 1500, "GET /accounts"], "isController": false}, {"data": [0.5852142857142857, 500, 1500, "GET /journal-entries"], "isController": false}, {"data": [0.849, 500, 1500, "POST /journal-entries/bulk"], "isController": false}, {"data": [0.11316666666666667, 500, 1500, "GET /reports/profit-loss"], "isController": false}, {"data": [0.668, 500, 1500, "POST /auth/login"], "isController": false}, {"data": [0.17116666666666666, 500, 1500, "GET /reports/balance-sheet"], "isController": false}, {"data": [0.7623, 500, 1500, "GET /users/me"], "isController": false}, {"data": [0.08666666666666667, 500, 1500, "GET /reports/trial-balance"], "isController": false}, {"data": [0.7610714285714286, 500, 1500, "GET /periods"], "isController": false}]}, function(index, item){
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
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 46500, 0, 0.0, 1298.871075268825, 4, 16007, 904.0, 3711.0, 4508.9000000000015, 6430.94000000001, 149.83276729843465, 9101.841667999184, 150.10254242945777], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["GET /reports/account-ledger", 3000, 0, 0.0, 2469.0930000000003, 61, 16007, 1153.5, 6708.5, 8510.75, 12445.529999999968, 10.405358065713305, 7928.842200143595, 10.628910680406364], "isController": false}, {"data": ["GET /accounts", 7000, 0, 0.0, 1265.6440000000023, 9, 11720, 843.5, 2957.9000000000005, 3983.8499999999995, 6217.949999999999, 51.91376382203962, 2684.6614874961992, 50.89982312239041], "isController": false}, {"data": ["GET /journal-entries", 7000, 0, 0.0, 1041.5878571428575, 17, 10709, 655.5, 2633.0, 3317.95, 5267.729999999994, 51.81653983951677, 693.8052516988422, 51.158712673585406], "isController": false}, {"data": ["POST /journal-entries/bulk", 3000, 0, 0.0, 444.57400000000075, 10, 5381, 276.5, 1005.8000000000002, 1410.6499999999987, 2665.9199999999983, 9.88985992661724, 5.852788198759812, 12.767104126420431], "isController": false}, {"data": ["GET /reports/profit-loss", 3000, 0, 0.0, 2489.458666666664, 34, 10054, 2316.0, 3789.2000000000007, 4759.849999999996, 8415.98, 10.064952493424231, 64.78330262124912, 10.133755879609748], "isController": false}, {"data": ["POST /auth/login", 500, 0, 0.0, 746.2180000000006, 13, 4026, 485.5, 1794.4000000000005, 2227.3999999999996, 2884.000000000002, 16.4111990021991, 23.476925341352942, 4.519490350214987], "isController": false}, {"data": ["GET /reports/balance-sheet", 3000, 0, 0.0, 2037.8853333333311, 40, 9391, 1925.0, 3073.9, 4209.349999999998, 6953.819999999996, 10.257988408473098, 50.708923167666825, 10.348146509719445], "isController": false}, {"data": ["GET /users/me", 10000, 0, 0.0, 581.7730999999995, 4, 6807, 331.0, 1463.0, 1964.8999999999978, 3226.8499999999967, 32.4912679717326, 23.44828811631874, 31.856672894159697], "isController": false}, {"data": ["GET /reports/trial-balance", 3000, 0, 0.0, 3925.7706666666636, 39, 15761, 3826.0, 5752.8, 7640.399999999998, 12148.0, 9.889273105462506, 104.90934935999921, 9.976190544865984], "isController": false}, {"data": ["GET /periods", 7000, 0, 0.0, 565.099571428572, 5, 5320, 368.0, 1366.0, 1801.0, 2542.9399999999987, 51.92570173876921, 54.41042770087829, 50.860819183579615], "isController": false}]}, function(index, item){
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
