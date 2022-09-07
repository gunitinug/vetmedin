#!/bin/bash

# we start with stream of objects(data.json) with spanning year-month-day.
#
# let's create data.json with two entries (1st and 10th day of month) each in months feb, april, jun, aug, oct, dec for years 2019, 2020, 2021, 2022.
#
# go through each object and add to [year,month:]... string.
# from that string, get rid of duplicates.
# query data.json for matching year+month and store matching [since_epoch:]... separately for each year+month.
#    - store each year+month:[since_epoch:]...
#
# display all year+month combinations in whiptail.
# when year+month item is selected, display all matching since_epoch (representing each day)... in whiptail.
# when day item is selected, show in whiptail radiolist to turn each item (from items.json) on/off.
#
# so we have two string formats:
# - [year+month:]...
# - [year+month:[since_epoch:]...%]...
# these have to be generated afresh at start of script.
#
#

validate_date () {
    local d=$1
    local n=0
    
    # validate d
    n=$(date -d "$d" &>/dev/null; echo $?)
    [[ $n -gt 0 ]] && echo 1 || echo 0
}

# try parsing
YEAR_MONTH=""
YEAR_MONTH_DAY=""
#year_month="2019+Jan:2019+Feb:2020+Mar:2020+Apr:2019+Jan:2021+May:2021+Jun"
year_month=""
#year_month_day="2019+Jan:100:101%2019+Feb:200:201%2020+Mar:300:301%2020+Apr:400:401%2021+May:500:501%2021+Jun:600:601%"
year_month_day=""

construct_year_month () {
    while read s; do
	year_month+="$(date -d @"$s" +'%Y+%b'):"
    done < <(jq '.[]|.secs_epoch' data.json)

    # rid of duplicates year_month
    year_month=$(echo "$year_month" | sed -E 's/:$//')
    year_month=$(echo "$year_month" | tr ':' '\n' | sort | uniq | tr '\n' ':' | sed -E 's/:$//')    
}

construct_year_month_day () {
    while read t; do
	local m=$(echo "$t" | cut -d+ -f2)
	local y=$(echo "$t" | cut -d+ -f1)
	local date1=$(date -d "1 $m $y" +%s)
	local date2=$(date -d "1 $m $y +1 month -1 day 23:59:59" +%s)

	year_month_day+="$y+$m:"
	
	while read m; do
	    #echo m: "$m"
	    year_month_day+="$m:"
	done < <(jq -c --argjson d1 "$date1" --argjson d2 "$date2" '.[]|select(.secs_epoch>=$d1 and .secs_epoch<=$d2)|.secs_epoch' data.json)

	year_month_day=$(echo "$year_month_day" | sed -E 's/:$//')
	year_month_day+="%"
	
    done < <(echo "$year_month" | tr ':' '\n')
}

# test: year_month   PASS!
#echo year_month:
#echo "$year_month"

construct_YEAR_MONTH () {
     # add seconds since epoch to each YEAR_MONTH item
     while read line; do
	 local month_ym=$(echo $line | cut -d+ -f2)
	 local year_ym=$(echo $line | cut -d+ -f1)
	 local secs_ym=$(date -d "1 $month_ym $year_ym" +%s)
	 YEAR_MONTH+="$secs_ym+$line:"
     done < <(echo "$year_month" | tr ':' '\n')

     #YEAR_MONTH=$(echo $YEAR_MONTH | tr ':' '\n' | sort | tr '\n' ':' | sed -E 's/:$//')
     YEAR_MONTH=$(echo $YEAR_MONTH | sed -E 's/:$//' | tr ':' '\n' | sort | tr '\n' ':' | sed -E 's/:$//')
}

# test: YEAR_MONTH   PASS!
#echo YEAR_MONTH:
#echo "$YEAR_MONTH"



#construct_year_month
#construct_year_month_day
#construct_YEAR_MONTH


#echo year_month
#echo "$year_month"
#echo YEAR_MONTH
#echo "$YEAR_MONTH"
#echo "$year_month_day"

OLD_DATA=""
str_eoe=""

edit_old_entry () {
    local secs_epoch="$1"
    local yn=""
    local desc=""
    
    OLD_DATA=$(jq --argjson s "$secs_epoch" '(.[]|select(.secs_epoch==$s))' data.json)

    # show initial OLD_DATA
    while read id; do
	yn=$(jq -r --argjson i $id '.items[]|select(.id==$i)|.t' <<<"$OLD_DATA")
	desc=$(jq -r --argjson i $id '.[]|select(.id==$i)|.desc' items.json)
	str_eoe+="${secs_epoch},${id},${yn} $desc OFF "
    done < <(jq -c '.[].id' items.json)

    local done=1
    while :; do
	sel_eoe=$(whiptail --title "Daily checklist" --checklist "Toggle Y or N each item" 20 78 10 "DONE" "Done" ON $str_eoe 3>&1 1>&2 2>&3)
	#local count=$(echo "$sel_ane" | tr ' ' '\n' | wc -l)

	local cancel__=$?
	[[ -z "$sel_eoe" ]] && return 1
	[[ "$cancel__" -gt 0 ]] && return 1
	
	
	#echo count: $count
	
	while read sel_eoe_; do
	    sel_eoe_=$(echo $sel_eoe_ | tr -d '"')

	    if [[ "$sel_eoe_" == "DONE" ]]; then
		done=0
	    else
		local f2=$(echo "$sel_eoe_" | cut -d, -f2)  # item id to alter OLD_DATA
		local f3=$(echo "$sel_eoe_" | cut -d, -f3)  # current yn to toggle in OLD_DATA
		[[ "$f3" == "Y" ]] && f3="N" || f3="Y"

		# test f2, f3
		#echo f2: "$f2"
		#echo f3: "$f3"
		
		# update OLD_DATA
		OLD_DATA=$(jq --argjson i "$f2" --arg y "$f3" '(.items[]|select(.id==$i)).t|=$y' <<<"$OLD_DATA")
	    fi
	done < <(echo "$sel_eoe" | tr ' ' '\n')

	# show updated OLD_DATA
	str_eoe=""
	while read id; do
	    yn=$(jq -r --argjson i $id '.items[]|select(.id==$i)|.t' <<<"$OLD_DATA")
	    desc=$(jq -r --argjson i $id '.[]|select(.id==$i)|.desc' items.json)
	    str_eoe+="${secs_epoch},${id},${yn} $desc OFF "
	done < <(jq -c '.[].id' items.json)

	#echo modified str_ane: "$str_ane"
	
	[[ $done -eq 0 ]] && break
    done

    # update data.json here.
    # first remove original entry with the matching $secs_epoch,
    # then add the replacement OLD_DATA.
    jq --argjson s "$secs_epoch" 'del(.[]|select(.secs_epoch==$s))' data.json | jq --argjson d "$OLD_DATA" '.+[$d]' > /tmp/vetmedin-edit_old_entry.json
    cp /tmp/vetmedin-edit_old_entry.json data.json
    rm /tmp/vetmedin-edit_old_entry.json

}

show_year_month_day () {
    local ym="$1"
    ym=${ym#*+}

    local lines=""
    local p1=$(echo $ym | cut -d+ -f1)
    local p2=$(echo $ym | cut -d+ -f2)

    # test: ym   PASS!
    #echo ym: $ym

    # test: p1, p2   PASS!
    #echo p1: $p1 p2: $p2
    
    lines=$(echo $year_month_day | grep -Po "$p1\+$p2.+?%" | sed -E 's/%$//')
    lines=${lines#*:}

    # test: lines   PASS!
    #echo lines: $lines

    local str=""

    while read line; do
	local d_=$(date -d @$line)
	d_=$(echo $d_ | tr ' ' '_')
	str+="$line ________Entry_${d_} OFF "
    done < <(echo "$lines" | tr ':' '\n')

    sel_symd=$(whiptail --title "Entries from $p1 $p2" --radiolist "Choose entry to edit" 20 78 4 $str 3>&1 1>&2 2>&3)

    local cancel=$?
    [[ -z "$sel_symd" ]] && return 1
    [[ "$cancel" -gt 0 ]] && return 1
    
    edit_old_entry "$sel_symd"
}

show_year_month () {
    local str=""

    while read line; do
	# echo line: "$line"   PASS!
	str+="$line __________Entries_from_$(echo $line | cut -d+ -f3)_$(echo $line | cut -d+ -f2) "
    done < <(echo "$YEAR_MONTH" | tr ':' '\n')

    sel_sym=$(whiptail --title "VETMEDIN" --menu "Entries" 25 78 16 $str 3>&1 1>&2 2>&3)

    local cancel=$?
    [[ -z "$sel_sym" ]] && return 1
    [[ "$cancel" -gt 0 ]] && return 1
    
    show_year_month_day $sel_sym
}

# main menu entry
edit_entry () {
    show_year_month
}

do_to_delete () {
    local args=("$@")

    for s in "${args[@]}"; do
	jq --argjson s "$s" 'del(.[]|select(.secs_epoch==$s))' data.json > /tmp/vetmedin-do_to_delete.json
	cp /tmp/vetmedin-do_to_delete.json data.json
	rm /tmp/vetmedin-do_to_delete.json
    done
}

sel_symdfd=""
sel_symdfd_y=""

show_year_month_day_for_deletion () {
    local ym="$1"
    ym=${ym#*+}

    local lines=""
    local p1=$(echo $ym | cut -d+ -f1)
    local p2=$(echo $ym | cut -d+ -f2)

    # test: ym   PASS!
    #echo ym: $ym

    # test: p1, p2   PASS!
    #echo p1: $p1 p2: $p2
    
    lines=$(echo $year_month_day | grep -Po "$p1\+$p2.+?%" | sed -E 's/%$//')
    lines=${lines#*:}

    # test: lines   PASS!
    #echo lines: $lines

    local str=""

    while read line; do
	local d_=$(date -d @$line)
	d_=$(echo $d_ | tr ' ' '_')
	str+="$line ________Entry_${d_} OFF "
    done < <(echo "$lines" | tr ':' '\n')

    sel_symdfd=$(whiptail --title "Delete entries" --checklist "Choose entries for deletion" 20 78 10 $str 3>&1 1>&2 2>&3)

    local cancel__=$?
    [[ -z "$sel_symdfd" ]] && return 1
    [[ "$cancel__" -gt 0 ]] && return 1
    
    local to_delete=()
    local to_del_h=()
    while read sel_symdfd_; do
	sel_symdfd_=$(echo $sel_symdfd_ | tr -d '"')

        # construct array
	to_delete+=("$sel_symdfd_")
	to_del_h+=("$(date -d @"$sel_symdfd_") |")
	
    done < <(echo "$sel_symdfd" | tr ' ' '\n')

    # yes no to confirm
    sel_symdfd_y=$(whiptail --title "Are you sure to delete?" --yesno "${to_del_h[*]}" 8 78 3>&1 1>&2 2>&3)
    [[ $? -eq 0 ]] && do_to_delete "${to_delete[@]}" || return 1
}

show_year_month_for_deletion () {
    local str=""

    while read line; do
	# echo line: "$line"   PASS!
	str+="$line __________Entries_from_$(echo $line | cut -d+ -f3)_$(echo $line | cut -d+ -f2) "
    done < <(echo "$YEAR_MONTH" | tr ':' '\n')

    sel_symfd=$(whiptail --title "VETMEDIN" --menu "Entries" 25 78 16 $str 3>&1 1>&2 2>&3)

    local cancel=$?
    [[ -z "$sel_symfd" ]] && return 1
    [[ "$cancel" -gt 0 ]] && return 1
    
    show_year_month_day_for_deletion $sel_symfd
}

# main menu entry
delete_entries () {
    show_year_month_for_deletion
}

# add new entry - main menu item
# list all items
# show checklst and toggle items yes/no

NEW_DATA=$(cat <<END
{ "secs_epoch": -1, "items": [ { "id": 0, "t": "N" }, { "id": 1, "t": "N" }, { "id": 2, "t": "N" }, { "id": 3, "t": "N" }, { "id": 4, "t": "N" }, { "id": 5, "t": "N" }, { "id": 6, "t": "N" }, { "id": 7, "t": "N" }, { "id": 8, "t": "N" } ] }	     
END
)

date_ane=""
str_ane=""

add_new_entry () {
    while :; do
	local chk=1
	date_ane=$(whiptail --inputbox "Provide date(eg. 20 aug 2023 12:00 or 'now')" 8 39 --title "Date" 3>&1 1>&2 2>&3)
	local cancel="$?"

	# if selected 'cancel' then return to main menu.
	[[ "$cancel" -gt 0 ]] && return 1
	
	[[ "$date_ane" == "now" ]] && date_ane=$(date +'%e %b %G %H:%M') && break
	
	local pattern="^[0-9]{1,2} [A-Za-z]{3,9} [0-9]{4} [0-9]{1,2}:[0-9]{1,2}$"
	[[ -n "$date_ane"  ]] && [[ "$cancel" -eq 0 ]] && [[ $(validate_date "$date_ane") -eq 0 ]] && [[ "$date_ane" =~ $pattern ]] && chk=0
	[[ "$chk" -eq 0 ]] && break	
    done

    #local secs_epoch=$(date -d "$(date +'%d %b %Y')" +%s)
    local secs_epoch=$(date -d "$date_ane" +%s)
    local desc=""
    local yn=""

    NEW_DATA=$(jq --argjson s "$secs_epoch" '.secs_epoch|=$s' <<<"$NEW_DATA")
    
    # show initial NEW_DATA
    while read id; do
	yn=$(jq -r --argjson i $id '.items[]|select(.id==$i)|.t' <<<"$NEW_DATA")
	desc=$(jq -r --argjson i $id '.[]|select(.id==$i)|.desc' items.json)
	str_ane+="${secs_epoch},${id},${yn} $desc OFF "
    done < <(jq -c '.[].id' items.json)

    local done=1
    while :; do
	sel_ane=$(whiptail --title "Daily checklist" --checklist "$date_ane Toggle Y or N each item" 20 78 10 "DONE" "Done" ON $str_ane 3>&1 1>&2 2>&3)
	#local count=$(echo "$sel_ane" | tr ' ' '\n' | wc -l)

	# handle case where sel_ane is empty string or cancelled.
	local cancel2=$?
	[[ -z "$sel_ane" ]] && return 1
	[[ "$cancel2" -gt 0 ]] && return 1
	
	#echo count: $count
	
	while read sel_ane_; do
	    sel_ane_=$(echo $sel_ane_ | tr -d '"')

	    if [[ "$sel_ane_" == "DONE" ]]; then
		done=0
	    else
		local f2=$(echo "$sel_ane_" | cut -d, -f2)  # item id to alter NEW_DATA
		local f3=$(echo "$sel_ane_" | cut -d, -f3)  # current yn to toggle in NEW_DATA
		[[ "$f3" == "Y" ]] && f3="N" || f3="Y"

		# test f2, f3
		#echo f2: "$f2"
		#echo f3: "$f3"
		
		# update NEW_DATA
		NEW_DATA=$(jq --argjson i "$f2" --arg y "$f3" '(.items[]|select(.id==$i)).t|=$y' <<<"$NEW_DATA")
	    fi
	done < <(echo "$sel_ane" | tr ' ' '\n')

	# show updated NEW_DATA
	str_ane=""
	while read id; do
	    yn=$(jq -r --argjson i $id '.items[]|select(.id==$i)|.t' <<<"$NEW_DATA")
	    desc=$(jq -r --argjson i $id '.[]|select(.id==$i)|.desc' items.json)
	    str_ane+="${secs_epoch},${id},${yn} $desc OFF "
	done < <(jq -c '.[].id' items.json)

	#echo modified str_ane: "$str_ane"
	
	[[ $done -eq 0 ]] && break
    done

    # update data.json here.
    jq --argjson d "$NEW_DATA" '.+[$d]' data.json > /tmp/vetmedin-add_new_entry.json
    cp /tmp/vetmedin-add_new_entry.json data.json
    rm /tmp/vetmedin-add_new_entry.json
}

#add_new_entry
#echo "$NEW_DATA"

# add bulk of entires for testing
add_bulk () {
    while read s; do
	NEW_DATA=$(cat ./NEW_DATA.json)
	NEW_DATA=$(jq --argjson s "$s" '.secs_epoch|=$s' <<<"$NEW_DATA")

	# write NEW_DATA to data.json
	jq --argjson d "$NEW_DATA" '.+[$d]' data.json >/tmp/vetmedin-bulk.json
	cp /tmp/vetmedin-bulk.json data.json
	rm /tmp/vetmedin-bulk.json
    done < <(./gen-targets.sh)
}

#add_bulk


# main menu
year_month=""
year_month_day=""
YEAR_MONTH=""

construct_year_month
construct_year_month_day
construct_YEAR_MONTH

while :; do
    sel=$(whiptail --title "VETMEDIN" --menu "Daily chore checklist" 25 78 16 \
       "ADD_ENTRY" "Add new entry" \
       "EDIT_ENTRY" "Find entry to edit" \
       "DELETE_ENTRIES" "Delete entries" \
       "QUIT" "Quit" 3>&1 1>&2 2>&3)


    case "$sel" in
	"ADD_ENTRY")
	    add_new_entry

	    year_month=""
	    year_month_day=""
	    YEAR_MONTH=""
	    construct_year_month
	    construct_year_month_day
	    construct_YEAR_MONTH
	    ;;
	"EDIT_ENTRY")
	    edit_entry
	    ;;
	"DELETE_ENTRIES")
	    delete_entries

	    year_month=""
	    year_month_day=""
	    YEAR_MONTH=""
	    construct_year_month
	    construct_year_month_day
	    construct_YEAR_MONTH
	    ;;
	"QUIT")
	    break
	    ;;
	*)
	    ;;
    esac
done
