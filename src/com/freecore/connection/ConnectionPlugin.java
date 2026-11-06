package com.freecore.connection;

import com.google.inject.Inject;
import com.velocitypowered.api.event.Subscribe;
import com.velocitypowered.api.event.connection.PluginMessageEvent;
import com.velocitypowered.api.event.proxy.ProxyInitializeEvent;
import com.velocitypowered.api.proxy.ProxyServer;
import com.velocitypowered.api.proxy.messages.MinecraftChannelIdentifier;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;

/** Authenticated proxy-to-backend labels; no credentials, IPs or player history. */
public final class ConnectionPlugin {
    private final ProxyServer proxy;
    private final Logger logger;
    private static final MinecraftChannelIdentifier CHANNEL=MinecraftChannelIdentifier.from("freecore:connection");
    @Inject public ConnectionPlugin(ProxyServer proxy,Logger logger){this.proxy=proxy;this.logger=logger;}
    @Subscribe public void initialized(ProxyInitializeEvent event){
        proxy.getChannelRegistrar().register(CHANNEL);
        proxy.getScheduler().buildTask(this,()->{
            for(var player:proxy.getAllPlayers()) try{
                String host=player.getVirtualHost().map(h->h.getHostString()).orElse("");
                boolean bedrock=false, identityReliable=true;
                // Resolve through the installed plugin's loader; classloader failure is not evidence of Java identity.
                var floodgate=proxy.getPluginManager().getPlugin("floodgate");
                if(floodgate.isPresent()) try {
                    Object provider=floodgate.get().getInstance().orElseThrow();
                    Class<?> api=Class.forName("org.geysermc.floodgate.api.FloodgateApi",true,provider.getClass().getClassLoader());
                    Object instance=api.getMethod("getInstance").invoke(null);
                    Object answer=api.getMethod("isFloodgatePlayer",java.util.UUID.class).invoke(instance,player.getUniqueId());
                    if(answer instanceof Boolean)bedrock=(Boolean)answer;else identityReliable=false;
                }catch(ReflectiveOperationException|RuntimeException|LinkageError ignored){identityReliable=false;}
                String route=RouteLabels.classify(host,bedrock,identityReliable);
                var buffer=new ByteArrayOutputStream();try(var out=new DataOutputStream(buffer)){out.writeUTF(player.getUniqueId().toString());out.writeUTF(route);out.writeLong(System.currentTimeMillis());}
                byte[] bytes=buffer.toByteArray();player.getCurrentServer().ifPresent(server->server.sendPluginMessage(CHANNEL,bytes));
            }catch(Exception ignored){}
        }).repeat(5,TimeUnit.SECONDS).schedule();
        logger.info("FreeCore connection labels active; unknown hosts are never guessed; no IPs collected.");
    }
    @Subscribe public void rejectClientPackets(PluginMessageEvent event){
        if(CHANNEL.equals(event.getIdentifier()))event.setResult(PluginMessageEvent.ForwardResult.handled());
    }
}
