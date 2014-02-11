 _.templateSettings = {
  evaluate : /\{\[([\s\S]+?)\]\}/g,
  interpolate : /\{\{([\s\S]+?)\}\}/g
};

function capitaliseFirstLetter(string)
{
  return string.charAt(0).toUpperCase() + string.slice(1);
}

function getSchedule(week) {
  var dateTemplate = _.template($('#dateWeek').html());
  var oppTemplate = _.template($('#oponents').html());
  var today = new Date();
      today.setDate(today.getDate() + 7*week - today.getDay());
  var week_object = {
    w_open: dateFormat(today, 'd'),
    w_close: parseInt(dateFormat(today, 'd')) + 7,
    month: dateFormat(today, 'mmm'),
    year: dateFormat(today, 'yyyy')
  }
  var week_string = dateTemplate(week_object)

  $.ajax({
    url: "/nextschedule",
    type: "GET",
    //serialize the form and use it as data for our ajax request
    data: {week: week},
    //the type of data we are expecting back from server, could be json too
    accepts: 'application/json; charset=utf-8',
    dataType: 'json',
    success: function(data) {
      $('#begSchedule').empty()
      $('#intSchedule').empty()
      $('.cur_week').html(week_string);
      if (data['beg'].length == 0) {
        $('#begSchedule').append('No Games This Week.');
      } else {
        $.each(data['beg'], function(i,p) {
          var oponents = {p1: p['participants'][0],
                      p2: p['participants'][1]};
          $('#begSchedule').append(oppTemplate(oponents));
        })
      }
      if (data['int'].length == 0) {
        $('#intSchedule').append('No Games This Week.');
      } else {
        $.each(data['int'], function(i,p) {
          var oponents = {p1: p['participants'][0],
                      p2: p['participants'][1]};
          $('#intSchedule').append(oppTemplate(oponents));
        })
      }

    }
  });
}