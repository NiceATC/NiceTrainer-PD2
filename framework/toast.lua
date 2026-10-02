function NiceTrainer:Toast(msg)
    if not self._ws then return end
    self._toasts = self._toasts or {}
    
    local valid_toasts = {}
    for _, t in ipairs(self._toasts) do
        if alive(t) then table.insert(valid_toasts, t) end
    end
    self._toasts = valid_toasts
    
    local h = 45
    local spacing = 10
    
    for _, t in ipairs(self._toasts) do
        t:set_y(t:y() + h + spacing)
    end
    
    while #self._toasts >= 3 do
        local oldest = table.remove(self._toasts, 1)
        if alive(oldest) then oldest:parent():remove(oldest) end
    end
    
    local p = self._ws:panel():panel({ x = -500, y = 20, h = h, layer = 3000 })
    local bg = p:rect({ color = Color.black, alpha = 0.85, layer = 0 })
    p:rect({ color = Color(0.2, 0.6, 1.0), w = 4, layer = 1 })
    
    local txt = p:text({ 
        text = tostring(msg), 
        font = "fonts/font_medium_shadow_mf", font_size = 20, 
        color = Color.white, x = 15, y = 11, layer = 1 
    })
    
    local _, _, tw, _ = txt:text_rect()
    local final_w = math.max(150, tw + 30)
    p:set_w(final_w)
    bg:set_w(final_w)
    
    table.insert(self._toasts, p)
    
    p:animate(function(o)
        local t = 0
        while t < 0.2 do
            t = t + coroutine.yield()
            o:set_x(math.lerp(-final_w, 20, t / 0.2))
        end
        o:set_x(20)
        
        t = 0
        while t < 3 do t = t + coroutine.yield() end
        
        t = 0
        while t < 0.4 do
            t = t + coroutine.yield()
            o:set_alpha(1 - (t / 0.4))
        end
        
        if alive(o) then o:parent():remove(o) end
    end)
end
