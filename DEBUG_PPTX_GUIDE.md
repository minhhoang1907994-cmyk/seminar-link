GET /documents/:id/debug (chỉ dùng khi testing)

---

# Thêm vào routes.rb để debugging PPTX issue

resources :documents do
  member do
    # ... existing routes ...
    get :debug_status  # Mới thêm
  end
end
