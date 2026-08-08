from django.conf import settings
from django.urls import path, re_path
from django.views.static import serve

from . import views

urlpatterns = [
    path("", views.root),
    path("health", views.health),

    path("api/auth/login", views.login),
    path("api/auth/register", views.register),
    path("api/auth/logout", views.logout),
    path("api/auth/profile", views.profile),
    path("api/auth/update-profile", views.profile),
    path("api/auth/upload-document", views.upload_document),
    path("api/auth/chat", views.my_chat),
    path("api/auth/support", views.support),

    path("api/stocks", views.stock_list),
    path("api/stocks/<str:ticker>", views.stock_detail),

    path("api/transactions", views.transactions),
    path("api/transactions/all", views.transactions_all),
    path("api/transactions/<str:tx_id>/validate", views.validate_transaction),
    path("api/transactions/<str:tx_id>/reject", views.reject_transaction),

    path("api/admin/stats", views.admin_stats),
    path("api/admin/users", views.admin_users),
    path("api/admin/users/<str:user_id>/kyc", views.admin_user_kyc),
    path("api/admin/users/<str:user_id>/suspend", views.admin_user_suspend),
    path("api/admin/support", views.admin_support),
    path("api/admin/support/<str:ticket_id>/status", views.admin_ticket_status),
    path("api/admin/chat/<str:user_id>", views.admin_chat),

    re_path(r"^uploads/(?P<path>.*)$", serve, {"document_root": settings.UPLOAD_DIR}),
]
