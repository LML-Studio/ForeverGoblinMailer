-- Small native widget fixture. Records the real panel's layout, text, state and callbacks.
return function(env,f)
    f.widgets={}
    local function make(kind,parent,name,layer)
        local w={kind=kind,parent=parent,name=name,layer=layer or "ARTWORK",shown=true,visible=true,
            scripts={},width=0,height=0,x=0,y=0,scale=1,text="",enabled=true}
        f.widgets[#f.widgets+1]=w
        w.id=#f.widgets
        function w:GetParent() return self.parent end
        function w:IsShown() return self.shown and self.visible end
        function w:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
        function w:SetShown(v)
            if self.shown==v then return end
            self.shown=v
            local fn=self.scripts[v and "OnShow" or "OnHide"]
            if fn then fn(self) end
        end
        function w:Show() self:SetShown(true) end
        function w:Hide() self:SetShown(false) end
        function w:SetScript(key,fn) self.scripts[key]=fn end
        function w:RegisterEvent(e) if e=="MAIL_SHOW" then f.listener=self end end
        function w:SetSize(x,y) self.width,self.height=x,y end
        function w:SetWidth(x) self.width=x end
        function w:SetHeight(y) self.height=y end
        function w:GetWidth() return self.width end
        function w:GetHeight() return self.height end
        function w:SetScale(v) self.scale=v end
        function w:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
        function w:ClearAllPoints() self.all=nil end
        function w:SetAllPoints(p) self.all=p or self.parent end
        function w:SetPoint(point,p,against,x,y)
            self.anchor,self.relative,self.against,self.x,self.y=point,p,against,x or 0,-(y or 0)
        end
        function w:GetRight() return self.x+self.width end
        function w:GetCenter() return self.x+self.width/2,self.y+self.height/2 end
        function w:SetText(s) self.text=tostring(s or ""); if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
        function w:GetText() return self.text end
        function w:SetTextColor(r,g,b) self.color={r,g,b} end
        function w:SetColorTexture(r,g,b,a) self.color={r,g,b,a or 1} end
        function w:SetTexture(v) self.texture=v end
        function w:SetTexCoord(...) self.uv={...} end
        function w:SetDesaturated(v) self.gray=v end
        function w:SetFont(path,size) self.size=size; self.face=path; return true end
        function w:GetFont() return self.face or "Friz",self.size or 12,"" end
        function w:GetStringHeight()
            local size=self.size or 12
            if f.measure then return f.measure(self.text,self.width,size) end
            local count=math.max(1,math.ceil(#self.text*size*.55/math.max(1,self.width)))
            return (size+2)*count
        end
        function w:SetJustifyH(value) self.justify=value end
        function w:SetJustifyV(value) self.valign=value end
        function w:CreateFontString(_,l) return make("FontString",self,nil,l) end
        function w:CreateTexture(_,l) return make("Texture",self,nil,l) end
        function w:EnableMouse(v) self.mouse=v end
        function w:SetFontObject(obj) self.face,self.size=obj:GetFont() end
        function w:SetChecked(v) self.checked=v end
        function w:GetChecked() return self.checked end
        function w:SetVerticalScroll(v) self.scroll=v end
        function w:GetVerticalScroll() return self.scroll or 0 end
        function w:SetScrollChild(child) self.child=child end
        function w:SetThumbTexture(path) self.thumb=make("Texture",self); self.thumb.texture=path end
        function w:GetThumbTexture() return self.thumb end
        function w:SetMinMaxValues(lo,hi) self.low,self.high=lo,hi end
        function w:SetValue(v)
            self.value=math.max(self.low,math.min(self.high,v))
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,self.value) end
        end
        function w:ClearFocus() self.focus=false end
        function w:HasFocus() return self.focus end
        function w:SetOwner(owner) self.owner=owner end
        function w:IsOwned(owner) return self.owner==owner end
        function w:AddLine(line) self.text=self.text.."\n"..line end
        for _,k in ipairs({"SetWordWrap","SetShadowOffset","SetAutoFocus","SetMaxLetters","SetTextInsets",
            "SetFrameStrata","SetClampedToScreen","SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing",
            "EnableMouseWheel","SetOrientation","SetValueStep"}) do w[k]=function() end end
        return w
    end
    env.UIParent=make("Frame")
    env.UIParent:SetSize(2160,1215)
    env.GameFontHighlight,env.GameFontNormalLarge=make("Font"),make("Font")
    env.GameTooltip=make("Tooltip"); env.GameTooltip:Hide()
    for _,name in ipairs({"MailFrame","SendMailFrame","SendMailNameEditBox","SendMailSubjectEditBox",
        "SendMailBodyEditBox","SendMailMoney","SendMailCODButton","SendMailSendMoneyButton","OpenMailFrame"}) do
        env[name]=make("Frame",env.UIParent,name)
    end
    env.MailFrame:SetSize(370,490)
    env.SendMailFrame.visible,env.OpenMailFrame.visible,env.SendMailSendMoneyButton.checked=false,false,true
    env.SlashCmdList={}
    env.CreateFrame=function(kind,name,parent) return make(kind,parent,name) end
    function f.button(caption)
        for _,w in ipairs(f.widgets) do
            if w.caption==caption and w.scripts.OnClick and w:IsVisible() then return w end
        end
        error("No visible control named "..caption)
    end
    function f.click(caption) local w=f.button(caption); return w.scripts.OnClick(w) end
end
