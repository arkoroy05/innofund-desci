// Notifications Functions
async function loadNotifications() {
    try {
        const response = await fetch('/api/notifications');
        const data = await response.json();
        
        if (data.success) {
            updateNotificationsList(data.notifications);
            updateNotificationCount(data.unread_count);
        }
    } catch (error) {
        console.error('Error loading notifications:', error);
    }
}

function updateNotificationsList(notifications) {
    const notificationsList = document.getElementById('notificationsList');
    if (!notificationsList) return;
    
    notificationsList.innerHTML = '';

    if (!notifications || notifications.length === 0) {
        notificationsList.innerHTML = '<div class="no-notifications">No notifications</div>';
        return;
    }

    notifications.forEach(notification => {
        const notificationElement = createNotificationElement(notification);
        notificationsList.appendChild(notificationElement);
    });
}

function createNotificationElement(notification) {
    const div = document.createElement('div');
    div.className = `notification-item ${notification.read ? '' : 'unread'}`;
    
    let content = '';
    
    if (notification.type === 'token_request') {
        content = `
            <div class="notification-content">
                <p>Token request from ${notification.from_user_name} for ${notification.amount} AVAX</p>
                ${notification.message ? `<p class="notification-message">"${notification.message}"</p>` : ''}
                <div class="notification-actions">
                    <button onclick="handleTokenRequest('${notification.id}', true)" class="accept-btn">
                        <i class="fas fa-check"></i> Accept
                    </button>
                    <button onclick="handleTokenRequest('${notification.id}', false)" class="decline-btn">
                        <i class="fas fa-times"></i> Decline
                    </button>
                </div>
            </div>
            <span class="notification-time">${formatTimestamp(notification.timestamp)}</span>
        `;
    } else if (notification.type === 'token_request_accepted') {
        content = `
            <div class="notification-content">
                <p>${notification.message}</p>
            </div>
            <span class="notification-time">${formatTimestamp(notification.timestamp)}</span>
        `;
    } else if (notification.type === 'token_request_declined') {
        content = `
            <div class="notification-content">
                <p>${notification.message}</p>
            </div>
            <span class="notification-time">${formatTimestamp(notification.timestamp)}</span>
        `;
    }
    
    div.innerHTML = content;
    return div;
}

function updateNotificationCount(count) {
    const badge = document.getElementById('notificationCount');
    if (badge) {
        if (count > 0) {
            badge.textContent = count;
            badge.style.display = 'block';
        } else {
            badge.style.display = 'none';
        }
    }
}

function formatTimestamp(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;
    
    if (diff < 60000) { // less than 1 minute
        return 'Just now';
    } else if (diff < 3600000) { // less than 1 hour
        const minutes = Math.floor(diff / 60000);
        return `${minutes}m ago`;
    } else if (diff < 86400000) { // less than 1 day
        const hours = Math.floor(diff / 3600000);
        return `${hours}h ago`;
    } else {
        return date.toLocaleDateString();
    }
}

// Initialize notifications count on page load
document.addEventListener('DOMContentLoaded', function() {
    // Load notifications count for the badge
    loadNotifications();
});

// Check for new notifications periodically
setInterval(loadNotifications, 30000); // Check every 30 seconds

async function handleTokenRequest(notificationId, accept) {
    try {
        const response = await fetch('/api/handle_token_request', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                notification_id: notificationId,
                accept: accept
            })
        });

        const data = await response.json();
        if (data.success) {
            loadNotifications(); // Refresh notifications
            if (accept) {
                alert('Token request accepted and transaction completed!');
            } else {
                alert('Token request declined.');
            }
        } else {
            alert(data.error || 'Failed to process request');
        }
    } catch (error) {
        console.error('Error:', error);
        alert('An error occurred while processing the request');
    }
} 