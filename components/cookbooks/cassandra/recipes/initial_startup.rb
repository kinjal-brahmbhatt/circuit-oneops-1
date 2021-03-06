
# update rfc
if node.workorder.rfcCi.rfcAction !~ /add|replace/
  Chef::Log.info("rfcAction: #{node.workorder.rfcCi.rfcAction}")
  old_vals = node.workorder.rfcCi.ciBaseAttributes
  new_vals = node.workorder.rfcCi.ciAttributes
  changed = false
  new_vals.keys.each do |k|
    if old_vals.has_key?(k) && 
       old_vals[k] != new_vals[k]
       Chef::Log.info("changed: old #{k}:#{old_vals[k]} != new #{k}:#{new_vals[k]}")
       changed = true
    end
  end
  if changed
#    execute "/opt/cassandra/bin/nodetool drain ; service cassandra restart ; true"
  end
  return
end

private_ip = node.workorder.payLoad.ManagedVia[0][:ciAttributes][:private_ip]
env_map = { 'JVM_OPTS' => "-Dcassandra.join_ring=false" }

file "/etc/default/cassandra" do
  owner "root"
  group "root"
  mode "0644"
  content "JVM_OPTS=\"-Dcassandra.join_ring=false -Djava.rmi.server.hostname=#{private_ip}\""
  action :create
  not_if { node.workorder.box.ciAttributes.availability == "single" }
end


# by default it get started by the install
availability_mode = node.workorder.box.ciAttributes.availability 
if availability_mode == "single"

  service "cassandra" do
    action [ :enable, :start ]
  end

else
  service "cassandra" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable ]
  end
  
  # stop and cleanup
  execute "service cassandra stop; pkill -9f jsvc; true"
  
  ruby_block "startup" do
    block do
      replace_option = ""
      bash_option = ""
      #add cassandra.replace_address JVM option to cassandra-env.sh
      if node.has_key?("cassandra_replace_option") && !node.cassandra_replace_option.nil?
        bash_option = "JVM_OPTS=\\\"\\$JVM_OPTS #{node.cassandra_replace_option}\\\""
        cmd = "sed -i '$ a #{bash_option}' /opt/cassandra/conf/cassandra-env.sh"
        Chef::Log.info("Updating cassandra-env : #{cmd}")
        cmd_result = shell_out(cmd)
        cmd_result.error!
      end
      cmd = "service cassandra start"
      cmd_result = shell_out(cmd)
      cmd_result.error!
    end
  end

  execute "remove ring_join=false from /etc/default/cassandra" do
    command "sed -i 's/-Dcassandra.join_ring=false //g' /etc/default/cassandra"
  end  

end
