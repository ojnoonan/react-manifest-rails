var NotificationsIndex = function(props) {
  var fetchResult = useFetch('/api/notifications');

  return React.createElement('div', { className: 'notifications' },
    React.createElement('h1', null, 'Notifications'),
    fetchResult.loading
      ? React.createElement('p', null, 'Loading...')
      : React.createElement(NotificationList, { items: fetchResult.data })
  );
};
