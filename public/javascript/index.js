 _.templateSettings = {
  evaluate : /\{\[([\s\S]+?)\]\}/g,
  interpolate : /\{\{([\s\S]+?)\}\}/g
};


function getSchedule(week) {
  $('#begSchedule').empty()
  $('#intSchedule').empty()
  $.ajax({
    url: "/nextschedule",
    type: "GET",
    //serialize the form and use it as data for our ajax request
    data: {week: week},
    //the type of data we are expecting back from server, could be json too
    accepts: 'application/json; charset=utf-8',
    dataType: 'json',
    success: function(data) {
      var template = _.template($('#oponents').html());
      if (data['beg'].length == 0) {
        $('#begSchedule').append('No Games This Week.');
      } else {
        $.each(data['beg'], function(i,p) {
          var oponents = {p1: p['participants'][0],
                      p2: p['participants'][1]};
          $('#begSchedule').append(template(oponents));
        })
      }
      if (data['int'].length == 0) {
        $('#intSchedule').append('No Games This Week.');
      } else {
        $.each(data['int'], function(i,p) {
          var oponents = {p1: p['participants'][0],
                      p2: p['participants'][1]};
          $('#intSchedule').append(template(oponents));
        })
      }

    }
  });
}