local act = false

require 'samp.events'.onServerMessage = function(_, text)
   if text:find('У вас нет столько наркотиков!') and act then
      sampAddChatMessage('• {FFFF00}[AutoLomka]: {FFFFFF} Нарко закончилось, прекращаю свою работу.', -1)
   end
end

require 'samp.events'.onSendCommand = function(text)
   if text:find("^/nlomka") then
      act = not act
      sampAddChatMessage('• {FFFF00}[AutoLomka]: {FFFFFF}Прокачка ломки:: '..(act and 'запущена' or 'прекращена'), -1)
      lua_thread.create(function()
         while act do
            sampSendChat('/usedrugs 3')
            wait(7500)
         end
      end)
   end
end