<template>
  <tr>
      <td class="actionItemDate">{{actedAt}}</td>
      <td class="actionItemText">{{actionText}}</td>
  </tr>
</template>

<script>
export default{
  props: ['actedAt', 'actionText'],
}
</script>